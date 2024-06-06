#!/bin/python3
import os
import random
import argparse
import json
import requests
import hashlib
import time
import signal
import sys
import prometheus_client
import string
import paramiko
import subprocess
import ipinfo
import asyncio, asyncssh, aiohttp
import logging
import socket
import ipfs_api
import tempfile
import ssl
import re
from aiohttp import ClientSession, ClientConnectionError, ClientResponseError
from Crypto.Hash import keccak
from prometheus_client import CollectorRegistry, Counter, Summary, Histogram, Gauge, push_to_gateway
from prometheus_client.exposition import basic_auth_handler

job_label=None

logging.basicConfig(
    format='%(asctime)s %(levelname)-8s %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S')
logging.getLogger('aiohttp').setLevel(logging.ERROR)
logging.getLogger('asyncssh').setLevel(logging.ERROR)
logging.getLogger('asyncio').setLevel(logging.ERROR)

prometheus_client.REGISTRY.unregister(prometheus_client.GC_COLLECTOR)
prometheus_client.REGISTRY.unregister(prometheus_client.PLATFORM_COLLECTOR)
prometheus_client.REGISTRY.unregister(prometheus_client.PROCESS_COLLECTOR)

# Load configuration from file or environment variables
def load_config(config_file):
    global ssh_servers, http_servers, ipfs_servers, ipfs_get_servers, username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token
    with open(config_file, 'r') as f:
        config = json.load(f)

    ssh_servers = os.getenv('SSH_SERVERS', config['ssh_servers'])
    if isinstance(ssh_servers, str):
        ssh_servers = ssh_servers.split(',')

    http_servers = os.getenv('HTTP_SERVERS', config['http_servers'])
    if isinstance(http_servers, str):
        http_servers = http_servers.split(',')

    ipfs_servers = os.getenv('IPFS_SERVERS', config['ipfs_servers'])
    if isinstance(ipfs_servers, str):
        ipfs_servers = ipfs_servers.split(',')

    ipfs_get_servers = os.getenv('IPFS_GET_SERVERS', config['ipfs_get_servers'])
    if isinstance(ipfs_get_servers, str):
        ipfs_get_servers = ipfs_get_servers.split(',')

    prometheus_gw = os.getenv('PROMETHEUS_GW', config['prometheus_gw'])
    prometheus_pw = os.getenv('PROMETHEUS_PW', config['prometheus_pw'])
    prometheus_user = os.getenv('PROMETHEUS_USER', config['prometheus_user'])

    username = os.getenv('USERNAME', config['username'])
    ipinfo_token = os.getenv('IPINFO_TOKEN', config['ipinfo_token'])

def pgw_auth_handler(url, method, timeout, headers, data):
    global prometheus_user, prometheus_pw
    return basic_auth_handler(url, method, timeout, headers, data, prometheus_user, prometheus_pw)

registry = CollectorRegistry()
NO_MATCH = Counter('util_web3_storage_sha_fail',
                       'failed to download a file that would match in 15 attempts',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_NO_MATCH = Counter('util_web3_storage_repeat_sha_fail',
                       'failed to download a file that would match in 15 attempts',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

OLD_NO_MATCH = Counter('util_web3_storage_old_sha_fail',
                       'failed to download a file that would match in 15 attempts',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

DL_TIME = Gauge('util_web3_storage_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

DL_TIME_EXTREMES = Gauge('util_web3_storage_download_extremes',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_DL_TIME = Gauge('util_web3_storage_repeat_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_DL_TIME_EXTREMES = Gauge('util_web3_storage_repeat_download_extremes',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

OLD_DL_TIME = Gauge('util_web3_storage_old_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

OLD_DL_TIME_EXTREMES = Gauge('util_web3_storage_old_download_extremes',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'attempts', 'latitude', 'longitude', 'size'],
                       registry=registry)

def signal_handler(sig, frame):
    global args
    # This function will be called when Ctrl+C is pressed
    logging.info("Ctrl+C pressed. Cleaning up or running specific code...")
    push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)
    sys.exit(0)  # Exit the script gracefully

def fetch_data(url):
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

def generate_random_string(length):
    letters = string.ascii_letters + string.digits
    return ''.join(random.choice(letters) for _ in range(length))

def generate_random_json_data(size_in_kb):
    data = {}
    size_in_bytes = size_in_kb * 1024
    key_length = 10
    value_length = 50
    
    # Estimate the size of one item (key-value pair)
    sample_key = generate_random_string(key_length)
    sample_value = generate_random_string(value_length)
    sample_item_size = len(json.dumps({sample_key: sample_value}).encode('utf-8'))
    
    # Estimate the number of items needed
    num_items = size_in_bytes // sample_item_size

    for _ in range(num_items):
        key = generate_random_string(key_length)
        value = generate_random_string(value_length)
        data[key] = value

    # Adjust to ensure we meet or slightly exceed the desired size
    while len(json.dumps(data).encode('utf-8')) < size_in_bytes:
        key = generate_random_string(key_length)
        value = generate_random_string(value_length)
        data[key] = value

    return json.dumps(data, indent=4)

def get_ip_from_dns(dns_name):
    """
    This function attempts to resolve a DNS name and return the IP address.

    Args:
        dns_name: The DNS name to resolve, which may include a port.

    Returns:
        The IP address of the DNS name if successful, otherwise None.
    """
    # Split the input to separate the IP/DNS and port if present
    if ':' in dns_name:
        host, _ = dns_name.rsplit(':', 1)
    else:
        host = dns_name

    # Regular expression to check if the input is already an IP address
    ip_pattern = re.compile(r'^\d{1,3}(\.\d{1,3}){3}$')

    if ip_pattern.match(host):
        return dns_name  # Return the original input if it's an IP address with or without port

    try:
        # Use socket.gethostbyname to resolve the DNS name
        ip_address = socket.gethostbyname(host)
        return ip_address
    except socket.gaierror:
        # Handle potential DNS resolution errors
        print(f"Error resolving DNS name: {dns_name}")
        return None

async def kill_existing_processes(server, username, output_file):
    async with asyncssh.connect(server, username=username) as conn:
        """Kill processes using the specified output file."""
        find_process_command = f"ps -ef | grep {output_file} | awk '{{print $2}}'"
        result = await conn.run(find_process_command)
        pids = result.stdout.split()
        for pid in pids:
            kill_command = f"kill -9 {pid}"
            await conn.run(kill_command)

async def ipfs_get(ip, cid, server, username, expected_sha256, max_attempts=15):
    global args
    storage = 'Ipfs'
    attempts = 0
    cid = cid.split("?", 1)[0]
    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(ip)
    output_file = f"/tmp/{cid}"
    ipget_timeout = 15 * 60  # 15 minutes in seconds
    initial_start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with asyncssh.connect(server, username=username) as conn:
                # Kill any existing processes using the output file
                await kill_existing_processes(server, username, output_file)

                # Redirect output to a file
                ipget_command = f"ipget -o {output_file} {cid}"
                try:
                    await asyncio.wait_for(conn.run(ipget_command), timeout=ipget_timeout)
                except asyncio.TimeoutError:
                    logging.error(f"ipget command timed out on attempt {attempts}")
                    continue  # Retry if timeout occurs

                elapsed_time = time.time() - initial_start_time

                # Calculate SHA256 hash of the file
                sha_command = f"sha256sum {output_file} | cut -d ' ' -f1"
                sha256sum_result = await conn.run(sha_command)
                sha256sum_output = sha256sum_result.stdout.strip()

                # Compare the calculated SHA256 with the expected one
                if sha256sum_output == expected_sha256:
                    # Remove the temporary output file if it exists
                    remove_command = f"rm {output_file}"
                    await conn.run(remove_command)
                    return elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage

                # Remove the temporary output file if it exists
                remove_command = f"rm {output_file}"
                await conn.run(remove_command)
                await kill_existing_processes(server, username, output_file)

        except (asyncssh.Error, OSError) as exc:
            logging.error(f"SSH error on attempt {attempts}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    await kill_existing_processes(server, username, output_file)

    return 0, None, server_loc, server, ip, attempts, storage

async def ssh_curl(ip, swarmhash, server, username, expected_sha256, max_attempts=15):
    global args
    storage = 'Swarm'
    attempts = 0
    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(server)
    initial_start_time = time.time()
    
    while attempts < max_attempts:
        attempts += 1
        try:
            async with asyncssh.connect(server, username=username) as conn:
                curl_command = f"curl -sSL {ip}:1633/bzz/{swarmhash}"
                result = await conn.run(curl_command)
                elapsed_time = time.time() - initial_start_time

                sha256sum_output = hashlib.sha256(result.stdout.encode('utf-8')).hexdigest()

                if sha256sum_output == expected_sha256:
                    return elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage
                
        except (asyncssh.Error, OSError) as exc:
            logging.error(f"SSH error on attempt {attempts}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    return 0, None, server_loc, server, ip, attempts, storage

async def http_curl(url, swarmhash, expected_sha256, max_attempts=15):
    global args
    storage = 'Swarm'
    attempts = 0

    # Extract IP address and port if present
    if ':' in url:
        ip, port = url.split(':')
    else:
        ip = url
        port = None

    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(ip))
    initial_start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=3600)) as session:
                if port:
                    base_url_https = f'https://{ip}:{port}/bzz/{swarmhash}'
                    base_url_http = f'http://{ip}:{port}/bzz/{swarmhash}'
                else:
                    base_url_https = f'https://{ip}/bzz/{swarmhash}'
                    base_url_http = f'http://{ip}/bzz/{swarmhash}'

                try:
                    async with session.get(base_url_https) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTPS fetch on attempt {attempts}")
                except aiohttp.ClientConnectorSSLError:
                    logging.warning(f"SSL error, retrying with HTTP for {url}")
                    async with session.get(base_url_http) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTP fetch on attempt {attempts}")

                elapsed_time = time.time() - initial_start_time
                sha256sum_output = hashlib.sha256(content).hexdigest()

                if sha256sum_output == expected_sha256:

                    return elapsed_time, sha256sum_output, server_loc, get_ip_from_dns(ip), url, attempts, storage

        except Exception as exc:
            logging.error(f"HTTP error on attempt {attempts}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    return 0, None, None, None, url, attempts, storage

async def http_ipfs(url, cid, expected_sha256, max_attempts=15):
    global args
    storage = 'Ipfs'
    attempts = 0
    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(url))

    initial_start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=86400)) as session:
                async with session.get(f'https://{url}/ipfs/{cid}') as response:
                    content = await response.read()
                    elapsed_time = time.time() - initial_start_time
                    sha256sum_output = hashlib.sha256(content).hexdigest()

                    if sha256sum_output == expected_sha256:
                        #logging.info(f"{server_loc.city} {storage} SHA256 hashes match on attempt {attempts}")

                        return elapsed_time, sha256sum_output, server_loc, get_ip_from_dns(url), url, attempts, storage

        except Exception as exc:
            logging.error(f"HTTP error on attempt {attempts}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    return 0, None, server_loc, get_ip_from_dns(url), url, attempts, storage

def upload_file(data, url):
    headers = {
        "Content-Type": "application/json"
    }
    response = requests.post(url, data=data, headers=headers)
    return response

async def get_random_ip_from_server(server, username):
    try:
        async with asyncssh.connect(server, username=username) as conn:
            try:
                # Check if kubectl is available
                which_command = "which kubectl"
                which_result = await conn.run(which_command)

                if which_result.exit_status == 0:
                    # kubectl is available, get the IPs using kubectl
                    kubectl_command = "sudo kubectl get svc -n bee -o json | jq '.items[] | select(.metadata.labels.endpoint == \"api\").spec.clusterIP'"
                    result = await conn.run(kubectl_command, check=True)

                    ip_addresses = result.stdout.strip().split("\n")
                    if not ip_addresses or (len(ip_addresses) == 1 and ip_addresses[0] == ""):
                        ip_addresses = [os.environ.get('HOSTNAME', 'localhost')]  # Default to 'localhost' if HOSTNAME is not set
                else:
                    # kubectl is not available, use HOSTNAME
                    ip_addresses = [os.environ.get('HOSTNAME', 'localhost')]  # Default to 'localhost' if HOSTNAME is not set
            except asyncssh.ProcessError as e:
                if e.exit_status == 127:
                    logging.warning(f"kubectl not found on server {server}. Falling back to HOSTNAME.")
                    ip_addresses = [os.environ.get('HOSTNAME', 'localhost')]  # Default to 'localhost' if HOSTNAME is not set
                else:
                    raise e

            chosen_ips = random.sample(ip_addresses, min(1, len(ip_addresses)))
            return server, chosen_ips

    except asyncssh.Error as exc:
        logging.error(f"get ip: SSH error on server {server}: {exc}")
        ip_addresses = [os.environ.get('HOSTNAME', 'localhost')]  # Default to 'localhost' if HOSTNAME is not set
        return server, ip_addresses

    except Exception as exc:
        logging.error(f"get ip: Unexpected error on server {server}: {exc}")
        ip_addresses = [os.environ.get('HOSTNAME', 'localhost')]  # Default to 'localhost' if HOSTNAME is not set
        return server, ip_addresses

async def get_random_ip_from_servers(servers, username):
    server_user_ips = {}
    tasks = [get_random_ip_from_server(server, username) for server in servers]
    results = await asyncio.gather(*tasks)

    for server, ips in results:
        server_user_ips[server] = ips

    return server_user_ips

async def main(args):
    global ssh_servers, http_servers, ipfs_servers, ipfs_get_servers, username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token, job_label
    repeat_count = args.repeat
    continuous = args.continuous
    references_file = "references.json"
    
    # Read existing references from the file
    if os.path.exists(references_file):
        with open(references_file, 'r') as f:
            references = json.load(f)
    else:
        references = {"swarm": {}, "ipfs": {}}

    if args.upload:
        while True:
            for r in range(repeat_count):
                server_user_ips = await get_random_ip_from_servers(ssh_servers, username)

                random_json = generate_random_json_data(args.size)
                sha256_hash = hashlib.sha256(random_json.encode('utf-8')).hexdigest()
                logging.info(f'Generated {args.size}kb file. SHA256 hash of upload: {sha256_hash}')

                start_upload_time = time.time()
                response = upload_file(random_json, args.url)
                upload_duration = time.time() - start_upload_time
                logging.info(f'Upload to swarm duration: {upload_duration}')
                
                # Upload to IPFS using a temporary file
                with tempfile.NamedTemporaryFile(delete=False, mode='w', suffix='.json') as tmpfile:
                    tmpfile.write(random_json)
                    tmpfile.flush()  # Ensure all data is written
                    ipfs_response = ipfs_api.http_client.add(tmpfile.name)
                    ipfs_hash = ipfs_response['Hash']
                    ipfs_file_name = ipfs_response['Name']
                    cid = ipfs_hash + '?filename=' + ipfs_file_name
                    logging.info(f'Successfully uploaded file to IPFS. cid: {cid}')
                    references.setdefault("ipfs", {}).setdefault(str(args.size), []).append({"cid": cid, "sha256": sha256_hash})

                if 200 <= response.status_code < 300:
                    response_data = response.json()
                    response_file_swarmhash = response_data.get("reference", "")
                    logging.info(f'Successfully uploaded file. Swarmhash: {response_file_swarmhash}')
                    logging.info(f'https://bee-3.dev.fairdatasociety.org/bzz/{response_file_swarmhash}')
                    references.setdefault("swarm", {}).setdefault(str(args.size), []).append({"swarmhash": response_file_swarmhash, "sha256": sha256_hash})
                else:
                    logging.info(f'Error: Failed to upload: {response.status_code}')

                # Save references to JSON file after each upload
                with open(references_file, 'w') as f:
                    json.dump(references, f, indent=4)

                ssh_tasks = []
                for server, chosen_ips in server_user_ips.items():
                    for ip in chosen_ips:
                        task = ssh_curl(ip, response_file_swarmhash, server, username, sha256_hash)
                        ssh_tasks.append(task)

                http_tasks = []
                for url in http_servers:
                    task = http_curl(url, response_file_swarmhash, sha256_hash)
                    http_tasks.append(task)

                ipfs_tasks = []
                for url in ipfs_servers:
                    task = http_ipfs(url, cid, sha256_hash)
                    ipfs_tasks.append(task)

                all_tasks = ssh_tasks + http_tasks + ipfs_tasks
                results = await asyncio.gather(*all_tasks, return_exceptions=True)

                fastest_time = float('inf')
                fastest_server = None
                fastest_ip = None
                fastest_attempts = 0

                slowest_time = 0
                slowest_server = None
                slowest_ip = None
                slowest_attempts = 0

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage = result
                        logging.info("-----------------START-----------------------")
                        logging.info(f"size: {args.size}kb")
                        logging.info(f"{storage} initial download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts. Size {args.size} ")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                            DL_TIME.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=args.size).set(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            NO_MATCH.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=args.size).inc()
                        logging.info("-----------------END-------------------------")

                        if elapsed_time < fastest_time:
                            fastest_time = elapsed_time
                            fastest_server = server
                            fastest_ip = ip
                            fastest_attempts = attempts

                        if elapsed_time > slowest_time:
                            slowest_time = elapsed_time
                            slowest_server = server
                            slowest_ip = ip
                            slowest_attempts = attempts

                        push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)
                logging.info("-----------------SUMMARY START-----------------------")
                logging.info(f"Fastest time: {fastest_time} for server {fastest_server} and IP {fastest_ip} with {fastest_attempts} attempts")
                logging.info(f"Slowest time: {slowest_time} for server {slowest_server} and IP {slowest_ip} with {slowest_attempts} attempts")
                DL_TIME_EXTREMES.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=args.size).set(fastest_time)
                DL_TIME_EXTREMES.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=args.size).set(slowest_time)

                logging.info("-----------------SUMMARY END-------------------------")

            push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)
            logging.info('All repeats done')
            if not continuous:
                break

    elif args.gateway:
        #server_user_ips = await get_random_ip_from_servers(ssh_servers, username)
        for size, swarm_entries in references["swarm"].items():
            for entry in swarm_entries:
                swarmhash = entry["swarmhash"]
                sha256_hash = entry["sha256"]
                ssh_tasks = []
                #for server, chosen_ips in server_user_ips.items():
                #    for ip in chosen_ips:
                #        task = ssh_curl(ip, swarmhash, server, username, sha256_hash)
                #        ssh_tasks.append(task)

                http_tasks = []
                for url in http_servers:
                    task = http_curl(url, swarmhash, sha256_hash)
                    http_tasks.append(task)

                all_tasks = ssh_tasks + http_tasks
                results = await asyncio.gather(*all_tasks, return_exceptions=True)

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage  = result
                        logging.info("-----------------START-----------------------")
                        logging.info(f"{storage} gateway download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                            REPEAT_DL_TIME.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            REPEAT_NO_MATCH.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).inc()
                        logging.info("-----------------END-------------------------")

                        push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)

        for size, ipfs_entries in references["ipfs"].items():
            for entry in ipfs_entries:
                cid = entry["cid"]
                sha256_hash = entry["sha256"]
                ipfs_tasks = []
                for url in ipfs_servers:
                    task = http_ipfs(url, cid, sha256_hash)
                    ipfs_tasks.append(task)

                results = await asyncio.gather(*ipfs_tasks, return_exceptions=True)

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage = result
                        logging.info("-----------------START-----------------------")
                        logging.info(f"{storage} gateway download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                            REPEAT_DL_TIME.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            REPEAT_NO_MATCH.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).inc()
                        logging.info("-----------------END-------------------------")

                        push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)

    elif args.download:
        server_user_ips = await get_random_ip_from_servers(ssh_servers, username)
        for size, swarm_entries in references["swarm"].items():
            for entry in swarm_entries:
                swarmhash = entry["swarmhash"]
                sha256_hash = entry["sha256"]
                ssh_tasks = []
                for server, chosen_ips in server_user_ips.items():
                    for ip in chosen_ips:
                        task = ssh_curl(ip, swarmhash, server, username, sha256_hash)
                        ssh_tasks.append(task)

                #all_tasks = ssh_tasks + http_tasks
                results = await asyncio.gather(*ssh_tasks, return_exceptions=True)

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage = result
                        logging.info("-----------------START-----------------------")
                        logging.info(f"{storage} old data download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                            OLD_DL_TIME.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            OLD_NO_MATCH.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).inc()
                        logging.info("-----------------END-------------------------")

                        push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)

        for size, ipfs_entries in references["ipfs"].items():
            for entry in ipfs_entries:
                cid = entry["cid"]
                sha256_hash = entry["sha256"]

                ipfs_get_tasks = []
                for ip in ipfs_get_servers:
                    task = ipfs_get(ip, cid, ip, username, sha256_hash)
                    ipfs_get_tasks.append(task)

                results = await asyncio.gather(*ipfs_get_tasks, return_exceptions=True)

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage = result
                        logging.info("-----------------START-----------------------")
                        logging.info(f"{storage} old data download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                            OLD_DL_TIME.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            OLD_NO_MATCH.labels(storage=storage, server=server, attempts=attempts, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).inc()
                        logging.info("-----------------END-------------------------")

                        push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)

if __name__ == '__main__':
    logging.info('Welcome to web3 storage speed test')
    hostname = os.getenv('HOSTNAME', 'unknown')
    job_label = f'web3storage_speed_{hostname}'
    load_config('config.json')
    parser = argparse.ArgumentParser(description='Swarm speed test for Gnosis.')
    parser.add_argument('--url', type=str, default="https://bee-1.fairdatasociety.org/bzz", help='URL for uploading data')
    parser.add_argument('--size', type=int, default=100, help='size of data in kb')
    parser.add_argument('--repeat', type=int, help='Number of times to repeat the upload process', default=1)
    parser.add_argument('--continuous', action='store_true', help='Continuously upload chunks (overrides --repeat)')
    parser.add_argument('--upload', action='store_true', help='Upload')
    parser.add_argument('--gateway', action='store_true', help='Gateways Download')
    parser.add_argument('--download', action='store_true', help='Download')

    args = parser.parse_args()
    signal.signal(signal.SIGINT, signal_handler)
    asyncio.run(main(args))


