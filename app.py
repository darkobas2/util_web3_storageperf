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
from aiohttp import ClientSession
from Crypto.Hash import keccak
from prometheus_client import CollectorRegistry, Summary, Histogram, Gauge, push_to_gateway
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
    global ssh_servers, http_servers, ipfs_servers, username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token
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

    prometheus_gw = os.getenv('PROMETHEUS_GW', config['prometheus_gw'])
    prometheus_pw = os.getenv('PROMETHEUS_PW', config['prometheus_pw'])
    prometheus_user = os.getenv('PROMETHEUS_USER', config['prometheus_user'])

    username = os.getenv('USERNAME', config['username'])
    ipinfo_token = os.getenv('IPINFO_TOKEN', config['ipinfo_token'])

def pgw_auth_handler(url, method, timeout, headers, data):
    return basic_auth_handler(url, method, timeout, headers, data, prometheus_user, prometheus_pw)

registry = CollectorRegistry()
DL_TIME = Gauge('util_web3_storage_download_time',
                       'Time spent processing request',
                       labelnames=['status', 'group', 'version'],
                       registry=registry)

UL_TIME = Gauge('util_web3_storage_upload_time',
                       'Time spent processing request',
                       labelnames=['status', 'group', 'version'],
                       registry=registry)

def signal_handler(sig, frame):
    global args
    # This function will be called when Ctrl+C is pressed
    logging.info("Ctrl+C pressed. Cleaning up or running specific code...")
    #cleanup_prometheus(args)
    #push_to_gateway(args.prometheus_push_url, job=job_label, registry=registry, handler=pgw_auth_handler)
    sys.exit(0)  # Exit the script gracefully

def fetch_data(url):
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

#def cleanup_prometheus(args):
#    push_to_gateway(args.prometheus_push_url, job=job_label, registry=registry, handler=pgw_auth_handler)


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
      dns_name: The DNS name to resolve.

  Returns:
      The IP address of the DNS name if successful, otherwise None.
  """
  try:
    # Use socket.gethostbyname to resolve the DNS name
    ip_address = socket.gethostbyname(dns_name)
    return ip_address
  except socket.gaierror:
    # Handle potential DNS resolution errors
    print(f"Error resolving DNS name: {dns_name}")
    return None

async def ssh_curl(ip, swarmhash, server, username, expected_sha256, max_attempts=5):
    storage = 'Swarm'
    attempts = 0
    start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with asyncssh.connect(server, username=username) as conn:
                curl_command = f"curl -sSL {ip}:1633/bzz/{swarmhash}"
                result = await conn.run(curl_command)
                elapsed_time = time.time() - start_time
                sha256sum_output = hashlib.sha256(result.stdout.encode('utf-8')).hexdigest()
                ipinfo_handler = ipinfo.getHandler(ipinfo_token)
                server_loc = ipinfo_handler.getDetails(server)
                
                if sha256sum_output == expected_sha256:
                    return elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage
        except (asyncssh.Error, OSError) as exc:
            logging.error(f"SSH error on attempt {attempts}: {exc}")

    elapsed_time = time.time() - start_time
    return elapsed_time, None, None, server, ip, attempts, storage

async def http_curl(url, swarmhash, expected_sha256, max_attempts=5):
    storage = 'Swarm'
    attempts = 0
    start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=86400)) as session:
                async with session.get('https://' + url + '/bzz/' + swarmhash) as response:
                    content = await response.read()
                    elapsed_time = time.time() - start_time
                    sha256sum_output = hashlib.sha256(content).hexdigest()
                    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
                    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(url))
                    
                    if sha256sum_output == expected_sha256:
                        return elapsed_time, sha256sum_output, server_loc, get_ip_from_dns(url), url, attempts, storage
        except Exception as exc:
            logging.error(f"HTTP error on attempt {attempts}: {exc}")

    elapsed_time = time.time() - start_time
    return elapsed_time, None, None, get_ip_from_dns(url), url, attempts, storage

async def http_ipfs(url, cid, expected_sha256, max_attempts=5):
    storage = 'Ipfs'
    attempts = 0
    start_time = time.time()

    while attempts < max_attempts:
        attempts += 1
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=86400)) as session:
                async with session.get('https://' + url + '/ipfs/' + cid) as response:
                    content = await response.read()
                    elapsed_time = time.time() - start_time
                    sha256sum_output = hashlib.sha256(content).hexdigest()
                    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
                    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(url))

                    if sha256sum_output == expected_sha256:
                        return elapsed_time, sha256sum_output, server_loc, get_ip_from_dns(url), url, attempts, storage
        except Exception as exc:
            logging.error(f"HTTP error on attempt {attempts}: {exc}")

    elapsed_time = time.time() - start_time
    return elapsed_time, None, None, get_ip_from_dns(url), url, attempts, storage

def upload_file(data, url):
    headers = {
        "Content-Type": "application/json"
    }
    response = requests.post(url, data=data, headers=headers)
    return response

async def get_random_ip_from_server(server, username):
    async with asyncssh.connect(server, username=username) as conn:
        command = "sudo kubectl get svc -n bee -o json | jq '.items[] | select(.metadata.labels.endpoint == \"api\").spec.clusterIP'"
        result = await conn.run(command, check=True)
        ip_addresses = result.stdout.strip().split("\n")
        chosen_ips = random.sample(ip_addresses, min(1, len(ip_addresses)))
        return server, chosen_ips

async def get_random_ip_from_servers(servers, username):
    server_user_ips = {}
    tasks = [get_random_ip_from_server(server, username) for server in servers]
    results = await asyncio.gather(*tasks)

    for server, ips in results:
        server_user_ips[server] = ips

    return server_user_ips

async def main(args):
    global ssh_servers, http_servers, ipfs_servers, username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token
    repeat_count = args.repeat
    continuous = args.continuous

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
                # Upload to IPFS using a temporary file
                with tempfile.NamedTemporaryFile(delete=False, mode='w', suffix='.json') as tmpfile:
                    tmpfile.write(random_json)
                    tmpfile.flush()  # Ensure all data is written
                    #cid = ipfs_api.publish(tmpfile.name)
                    ipfs_response = ipfs_api.http_client.add(tmpfile.name)
                    ipfs_hash = ipfs_response['Hash']
                    ipfs_file_name = ipfs_response['Name']
                    cid = ipfs_hash + '?filename=' + ipfs_file_name
                    logging.info(f'Successfully uploaded file to IPFS. cid: {cid}')

                if 200 <= response.status_code < 300:
                    response_data = response.json()
                    response_file_swarmhash = response_data.get("reference", "")
                    logging.info(f'Successfully uploaded file. Swarmhash: {response_file_swarmhash}')
                    logging.info(f'https://bee-3.dev.fairdatasociety.org/bzz/{response_file_swarmhash}')
                else:
                    logging.info(f'Error: Failed to upload: {response.status_code}')

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
                        logging.info(f"{storage} download from {server} took {elapsed_time} seconds with {attempts} attempts. Location: {server_loc.city if server_loc else 'Unknown'}")

                        if sha256_hash == sha256sum_output:
                            logging.info("SHA256 hashes match.")
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")

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

                logging.info(f"Fastest time: {fastest_time} for server {fastest_server} and IP {fastest_ip} with {fastest_attempts} attempts")
                logging.info(f"Slowest time: {slowest_time} for server {slowest_server} and IP {slowest_ip} with {slowest_attempts} attempts")

            logging.info('All repeats done')
            if not continuous:
                break


if __name__ == '__main__':
    logging.info('Welcome to web3 storage speed test')
    hostname = os.getenv('HOSTNAME', 'unknown')
    job_label = f'web3storage_speed_{hostname}'
    load_config('config.json')
    parser = argparse.ArgumentParser(description='Swarm speed test for Gnosis.')
    parser.add_argument('--url', type=str, default="https://bee-1.fairdatasociety.org/bzz", help='URL for uploading data')
    parser.add_argument('--size', type=int, default=100, help='size of data in kb')
    parser.add_argument('--prometheus_push_url', type=str, help='Push URL for Prometheus metrics', default='')
    parser.add_argument('--repeat', type=int, help='Number of times to repeat the upload process', default=1)
    parser.add_argument('--continuous', action='store_true', help='Continuously upload chunks (overrides --repeat)')
    parser.add_argument('--upload', action='store_true', help='Upload')

    args = parser.parse_args()
    signal.signal(signal.SIGINT, signal_handler)
    asyncio.run(main(args))
    registry = CollectorRegistry()
    time.sleep(10)
    #cleanup_prometheus(args)


