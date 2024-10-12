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
import json
import datetime
import pytz

from pathlib import Path
from aiohttp import ClientSession, ClientConnectionError, ClientResponseError
from Crypto.Hash import keccak
from prometheus_client import CollectorRegistry, Counter, Summary, Histogram, Gauge, push_to_gateway
from prometheus_client.exposition import basic_auth_handler
from ritual_arweave.file_manager import FileManager

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

references_file = "references.json"

# Read existing references from the file
if os.path.exists(references_file):
    with open(references_file, 'r') as f:
        references = json.load(f)
else:
    references = {"swarm": {}, "ipfs": {}, "arweave": {}}

# Load configuration from file or environment variables
def load_config(config_file):
    global username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token, ipfs_data_dir, swarm_ul_server, swarm_dl_servers, ipfs_ul_server, ipfs_dl_servers, arw_ul_server, arw_dl_servers, swarm_batch_id
    with open(config_file, 'r') as f:
        config = json.load(f)

    swarm_dl_servers = os.getenv('SWARM_DL_SERVERS', config['swarm_dl_servers'])
    if isinstance(swarm_dl_servers, str): 
        swarm_dl_servers = swarm_dl_servers.split(',')

    ipfs_dl_servers = os.getenv('IPFS_DL_SERVERS', config['ipfs_dl_servers'])
    if isinstance(ipfs_dl_servers, str):
        ipfs_dl_servers = ipfs_dl_servers.split(',')

    prometheus_gw = os.getenv('PROMETHEUS_GW', config['prometheus_gw'])
    prometheus_pw = os.getenv('PROMETHEUS_PW', config['prometheus_pw'])
    prometheus_user = os.getenv('PROMETHEUS_USER', config['prometheus_user'])

    username = os.getenv('USERNAME', config['username'])
    ipinfo_token = os.getenv('IPINFO_TOKEN', config['ipinfo_token'])
    ipfs_data_dir = os.getenv('IPFS_DATA_DIR', config['ipfs_data_dir'])
    ipfs_ul_server = os.getenv('IPFS_UL_SERVER', config['ipfs_ul_server'])
    swarm_ul_server = os.getenv('SWARM_UL_SERVER', config['swarm_ul_server'])
    swarm_batch_id = os.getenv('SWARM_BATCH_ID', config['swarm_batch_id'])

    arw_ul_server = os.getenv('ARW_UL_SERVER', config['arw_ul_server'])
    arw_dl_servers = os.getenv('ARW_DL_SERVERS', config['arw_dl_servers'])
    if isinstance(arw_dl_servers, str):
        arw_dl_servers = arw_dl_servers.split(',')

def load_pinata_credentials(filename='.pinata.key'):
    """Loads Pinata API Key and Secret from a file.

    Args:
        filename (str, optional): The name of the file containing the credentials. 
                                    Defaults to '.pinata.key'.

    Returns:
        tuple: A tuple containing (API Key, API Secret) or (None, None) if not found.
    """
    jwt = None
    try:
        with open(filename, 'r') as f:
            for line in f:
                if line.startswith('JWT:'):
                    jwt = line.split(':')[1].strip()
    except FileNotFoundError:
        logging.warning(f"Pinata credentials file '{filename}' not found.")
    return jwt

def pgw_auth_handler(url, method, timeout, headers, data):
    global prometheus_user, prometheus_pw
    return basic_auth_handler(url, method, timeout, headers, data, prometheus_user, prometheus_pw)

registry = CollectorRegistry()
NO_MATCH = Counter('util_web3_storage_sha_fail',
                       'failed to download a file that would match',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_NO_MATCH = Counter('util_web3_storage_repeat_sha_fail',
                       'failed to download a file that would match',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

OLD_NO_MATCH = Counter('util_web3_storage_old_sha_fail',
                       'failed to download a file that would match',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

DL_TIME = Gauge('util_web3_storage_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

DL_TIME_SUM = Histogram('util_web3_storage_download_time_summary',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       buckets=[
                           0,
                           1,
                           10,
                           30,
                           60,
                           300,
                           600,
                           1000,
                           float('inf')  # Infinity for the last bucket
                       ],
                       registry=registry)

DL_TIME_EXTREMES = Gauge('util_web3_storage_download_extremes',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_DL_TIME = Gauge('util_web3_storage_repeat_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

REPEAT_DL_TIME_SUM = Histogram('util_web3_storage_repeat_download_summary',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       buckets=[
                           0, 
                           1, 
                           10,
                           30,
                           60,
                           300, 
                           600,
                           1000,
                           float('inf')  # Infinity for the last bucket
                       ],
                       registry=registry)

OLD_DL_TIME = Gauge('util_web3_storage_old_download_time',
                       'Time spent processing request',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       registry=registry)

OLD_DL_TIME_SUM = Histogram('util_web3_storage_old_download_summary',
                       'winners and loosers',
                       labelnames=['storage', 'server', 'latitude', 'longitude', 'size'],
                       buckets=[
                           0, 
                           1, 
                           10,
                           30,
                           60,
                           300, 
                           600,
                           1000,
                           float('inf')  # Infinity for the last bucket
                       ],
                       registry=registry)

def save_test_results(results, filename="results.json"):
    """Saves test results to a JSON file.

    Args:
        results (list): A list of test result dictionaries.
        filename (str, optional): The name of the JSON file. Defaults to "results.json".
    """
    try:
        with open(filename, 'r+') as file:
            data = json.load(file)
            data["tests"].extend(results)
            file.seek(0)  # Rewind to the beginning of the file
            json.dump(data, file, indent=4)
    except FileNotFoundError:
        with open(filename, 'w') as file:
            json.dump({"tests": results}, file, indent=4)

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
    key = generate_random_string(8)
    overhead = len(f'{{"{key}":""}}'.encode('utf-8'))
    value_length = size_in_bytes - overhead
    
    value = generate_random_string(value_length)
    data = {key: value}

    return json.dumps(data)

def generate_random_binary_data(size_in_kb):
    """
    Generates random binary data of the specified size in kilobytes.

    Args:
        size_in_kb (int): The size of the binary data to generate in kilobytes.

    Returns:
        bytes: A bytes object containing the random binary data.
    """
    size_in_bytes = size_in_kb * 1024
    return os.urandom(size_in_bytes)

def get_ip_from_dns(dns_name):
    """
    This function attempts to resolve a DNS name and return the IP address.

    Args:
        dns_name: The DNS name to resolve, which may include a protocol (http/https), a port, or neither.

    Returns:
        The IP address of the DNS name if successful, otherwise None.
    """

    # Remove protocol (http/https) if present
    if dns_name.startswith("http://") or dns_name.startswith("https://"):
        dns_name = dns_name[len("https://"):] if dns_name.startswith("https://") else dns_name[len("http://"):]

    # Split the input to separate the IP/DNS and port if present
    if ':' in dns_name:
        host, _ = dns_name.rsplit(':', 1)  # Take only the last colon
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

def extract_port(url):
    # Extract IP address and port if present
    if ':' in url:
        ip, port = url.split(':')
    else:
        ip = url
        port = None
    return ip,port

async def http_curl(url, swarmhash, expected_sha256, max_attempts, size):
    global args
    storage = 'Swarm'
    ip, port = extract_port(url)

    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(ip))
    initial_start_time = time.time()

    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=1000)) as session:
        for attempt in range(1, max_attempts + 1):
            try:
                if port:
                    base_url_https = f'https://{ip}:{port}/bzz/{swarmhash}'
                    base_url_http = f'http://{ip}:{port}/bzz/{swarmhash}'
                else:
                    base_url_https = f'https://{ip}/bzz/{swarmhash}'
                    base_url_http = f'http://{ip}/bzz/{swarmhash}'

                try:
                    async with session.get(base_url_http) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTPS fetch on attempt {attempt} for {url}")
                except aiohttp.ClientConnectorSSLError:
                    logging.warning(f"SSL error, retrying with HTTP for {url}")
                    async with session.get(base_url_https) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTP fetch on attempt {attempt} for {url}")

                elapsed_time = time.time() - initial_start_time
                sha256sum_output = hashlib.sha256(content).hexdigest()

                if sha256sum_output == expected_sha256:
                    return elapsed_time, 'true', server_loc, get_ip_from_dns(ip), url, attempt, storage, size, swarmhash

            except Exception as exc:
                logging.error(f"HTTP error on attempt {attempt} for {url}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    return 0, 'false', server_loc, get_ip_from_dns(ip), url, max_attempts, storage, size, swarmhash

async def http_ipfs(url, cid, expected_sha256, max_attempts, size):
    global args
    storage = 'Ipfs'
    ip, port = extract_port(url)

    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(ip))
    initial_start_time = time.time()

    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=1000)) as session:
        for attempt in range(1, max_attempts + 1):
            try:
                if port:
                    base_url_https = f'https://{ip}:{port}/ipfs/{cid}'
                    base_url_http = f'http://{ip}:{port}/ipfs/{cid}'
                else:
                    base_url_https = f'https://{ip}/ipfs/{cid}'
                    base_url_http = f'http://{ip}/ipfs/{cid}'
                try:
                    async with session.get(base_url_http) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTPS fetch on attempt {attempt} for {url}")
                except aiohttp.ClientConnectorSSLError:
                    logging.warning(f"SSL error, retrying with HTTP for {url}")
                    async with session.get(base_url_https) as response:
                        content = await response.read()
                        if response.status == 200:
                            logging.info(f"Successful HTTP fetch on attempt {attempt} for {url}")

                elapsed_time = time.time() - initial_start_time
                #content_str = json.loads(content)  # Trim trailing newline if present
                #sha256sum_output = hashlib.sha256(content_str.encode('utf-8')).hexdigest()
                sha256sum_output = hashlib.sha256(content).hexdigest()

                if sha256sum_output == expected_sha256:
                    logging.debug(f"IPFS: SHA256 hashes match on attempt {attempt} for {url}")
                    return elapsed_time, 'true', server_loc, get_ip_from_dns(url), url, attempt, storage, size, cid

            except Exception as exc:
                logging.error(f"IPFS: HTTP error on attempt {attempt} for {url}: {exc}")

    total_elapsed_time = time.time() - initial_start_time
    logging.debug(f"IPFS: Failed after {max_attempts} attempts for {url}")
    return 0, 'false', server_loc, get_ip_from_dns(url), url, max_attempts, storage, size, cid

async def http_arw(url, transaction_id, expected_sha256, max_attempts, size):
    global args
    storage = 'Arweave'
    ipinfo_handler = ipinfo.getHandler(ipinfo_token)
    server_loc = ipinfo_handler.getDetails(get_ip_from_dns(url))

    arw_file_manager = FileManager(api_url=url, wallet_path='./arw_wallet.json')

    initial_start_time = time.time()

    for attempt in range(1, max_attempts + 1):
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            try:
                # Perform the download operation in a non-blocking manner
                await asyncio.to_thread(arw_file_manager.download, temp_file.name, transaction_id)  # You don't need the result here (assuming synchronous download)
                elapsed_time = time.time() - initial_start_time

                # Read content of the downloaded file
                content = open(temp_file.name, 'rb').read()
                sha256sum_output = hashlib.sha256(content).hexdigest()

                if sha256sum_output == expected_sha256:
                    logging.debug(f"ARW: SHA256 hashes match on attempt {attempt} for {url}")
                    return elapsed_time, 'true', server_loc, get_ip_from_dns(url), url, attempt, storage, size, transaction_id

            except Exception as exc:
                pass
                #logging.error(f"ARW: HTTP error on attempt {attempt} for {url}: {exc}")

            finally:
                # Ensure temporary file is always deleted, even on exceptions
                os.remove(temp_file.name)

    total_elapsed_time = time.time() - initial_start_time
    logging.debug(f"ARW: Failed after {max_attempts} attempts for {url}")
    return 0, 'false', server_loc, get_ip_from_dns(url), url, max_attempts, storage, size, transaction_id

def upload_file(data, url_list):
    global swarm_batch_id
    headers = {
        "Content-Type": "application/json",
        "swarm-postage-batch-id": swarm_batch_id
    }
    url = f"https://{url_list[0]}"

    response = requests.post(url=url, data=data, headers=headers, timeout=600)
    return response

async def pin_json_to_ipfs(jwt, json_data, filename):
    """Pins JSON data to IPFS using Pinata's API.

    Args:
        api_key (str): Your Pinata API key.
        api_secret (str): Your Pinata API secret.
        json_data (dict): The JSON data to pin.
        filename (str): The filename to associate with the pinned data.

    Returns:
        dict: The response from the Pinata API if successful, otherwise None.
    """
    url = 'https://api.pinata.cloud/pinning/pinJSONToIPFS'
    headers = {
        'Authorization': 'Bearer ' + jwt
    }
    payload = {
        'pinataContent': json_data,
        'pinataMetadata': {'name': filename}
    }

    async with aiohttp.ClientSession() as session:
        try:
            async with session.post(url, json=payload, headers=headers) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    logging.error(f'Error pinning to Pinata: {response.status} - {await response.text()}')
        except aiohttp.ClientError as e:
            logging.error(f'Error pinning to Pinata: {e}')

    return None

async def pin_file_to_ipfs(jwt, file_path, filename, file_type="application/octet-stream"):
    """
    Pins a file to IPFS using Pinata's API.

    Args:
        jwt (str): Your Pinata JWT token.
        file_path (str): The path to the file to upload.
        filename (str): The filename to associate with the pinned data.
        file_type (str): The MIME type of the file being uploaded. Defaults to 'application/octet-stream'.

    Returns:
        dict: The response from the Pinata API if successful, otherwise None.
    """
    url = 'https://api.pinata.cloud/pinning/pinFileToIPFS'
    headers = {
        'Authorization': f'Bearer {jwt}'
    }

    form_data = aiohttp.FormData()

    # Open the file as a binary stream and add it to the form
    with open(file_path, 'rb') as file:
        form_data.add_field('file', file, filename=filename, content_type=file_type)

        # Optional: Add pinataMetadata
        pinata_metadata = {
            "name": filename,
        }
        form_data.add_field('pinataMetadata', json.dumps(pinata_metadata))

        # Optional: Add pinataOptions
        pinata_options = {
            "cidVersion": 1
        }
        form_data.add_field('pinataOptions', json.dumps(pinata_options))

        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, data=form_data, headers=headers) as response:
                    if response.status == 200:
                        return await response.json()
                    else:
                        logging.error(f'Error pinning file to Pinata: {response.status} - {await response.text()}')
            except aiohttp.ClientError as e:
                logging.error(f'Error pinning file to Pinata: {e}')

    return None

async def get_random_ip_from_servers(servers, username):
    server_user_ips = {}
    tasks = [get_random_ip_from_server(server, username) for server in servers]
    results = await asyncio.gather(*tasks)

    for server, ips in results:
        server_user_ips[server] = ips

    return server_user_ips

async def main(args):
    global username, prometheus_gw, prometheus_pw, prometheus_user, ipinfo_token, ipfs_data_dir, swarm_ul_server, swarm_dl_servers, ipfs_ul_server, ipfs_dl_servers, arw_ul_server, arw_dl_servers

    repeat_count = args.repeat
    continuous = args.continuous
    results_by_storage = {"Swarm": [], "Ipfs": [], "Arweave": []}  # Initialize a dictionary to store results by storage
    arw_file_manager = FileManager(api_url=arw_ul_server, wallet_path='./arw_wallet.json')

    PINATA_JWT = load_pinata_credentials()
    if not PINATA_JWT:
        logging.error("Pinata API Key or Secret not found. Exiting.")
        sys.exit(1)  # Exit if credentials are not found

    # Read existing references from the file
    if os.path.exists(references_file):
        with open(references_file, 'r') as f:
            references = json.load(f)
    else:
        references = {"swarm": {}, "ipfs": {}}

    if args.upload:
        while True:
            for r in range(repeat_count):

                #random_json = generate_random_json_data(args.size)
                random_bin = generate_random_binary_data(args.size)
                #sha256_hash = hashlib.sha256(random_json.encode('utf-8')).hexdigest()
                sha256_hash = hashlib.sha256(random_bin).hexdigest()
                logging.info(f'Generated {args.size}kb file. SHA256 hash of upload: {sha256_hash}')

                start_upload_time = time.time()
                #response = upload_file(random_json, swarm_ul_server)
                response = upload_file(random_bin, swarm_ul_server)
                upload_duration = time.time() - start_upload_time

                if 200 <= response.status_code < 300:
                    response_data = response.json()
                    response_file_swarmhash = response_data.get("reference", "")
                    logging.info(f'Successfully uploaded file. Swarmhash: {response_file_swarmhash}')
                    logging.info(f'https://download.gateway.ethswarm.org/bzz/{response_file_swarmhash}')

                    # Store reference, upload time, and SHA256 hash
                    references.setdefault("swarm", {}).setdefault(str(args.size), []).append({
                        "hash": response_file_swarmhash, 
                        "sha256": sha256_hash,
                        "upload_time": upload_duration,  # Add upload time here
                        "timestamp": datetime.datetime.now(pytz.utc).isoformat()
                    })
                    logging.info(f'Upload to swarm duration: {upload_duration}')
                else:
                    logging.info(f'Error: Failed to upload: {response.status_code}')
                

                # Upload to Arweave and pinata using a temporary file
                #with tempfile.NamedTemporaryFile(dir=ipfs_data_dir, delete=False, mode='w', suffix='.json') as tmpfile:
                with tempfile.NamedTemporaryFile(dir=ipfs_data_dir, delete=False, mode='wb', suffix='.bin') as tmpfile:
                    #tmpfile.write(random_json)
                    tmpfile.write(random_bin)
                    tmpfile.flush()  # Ensure all data is written

                    try:
                        with open(tmpfile.name, 'rb') as f:
                            files = {'file': f}
                            arw_start_upload_time = time.time()
                            arw_response = arw_file_manager.upload(tmpfile.name, tags_dict={'filename': tmpfile.name})
                            arw_upload_duration = time.time() - arw_start_upload_time
                            logging.info(f'Upload to arweave duration: {arw_upload_duration}')
                            arw_transaction_id = arw_response.id
                            if arw_transaction_id:
                                logging.info(f'Successfully uploaded file to ARWEAVE. transaction: {arw_transaction_id}')
                                # Store Arweave reference, upload time, and SHA256 hash
                                references.setdefault("arweave", {}).setdefault(str(args.size), []).append({
                                    "hash": arw_transaction_id, 
                                    "sha256": sha256_hash,
                                    "upload_time": arw_upload_duration,  # Add upload time here
                                    "timestamp": datetime.datetime.now(pytz.utc).isoformat()
                                })
                            else:
                                logging.warning(f"Failed to get transaction ID from Arweave response. Response: {arw_response}")
                    except Exception as e:
                        logging.error(f"Error uploading: {str(e)}")
                        
                    # Upload to Pinata
                    pinata_start_upload_time = time.time()
                    #pinata_response = await pin_json_to_ipfs(PINATA_JWT, random_json, f'speedtest-{args.size}kb-{r}')
                    pinata_response = await pin_file_to_ipfs(PINATA_JWT, tmpfile.name, f'speedtest-{args.size}kb-{r}')
                    pinata_upload_duration = time.time() - pinata_start_upload_time
                    
                    if pinata_response:
                        ipfs_hash = pinata_response['IpfsHash']
                        ipfs_pin_size = pinata_response['PinSize']
                        ipfs_timestamp = pinata_response['Timestamp']

                        logging.info(f'Successfully uploaded file to Pinata. IPFS Hash: {ipfs_hash}, Pin Size: {ipfs_pin_size}, Timestamp: {ipfs_timestamp}')
                    else:
                        logging.warning(f"Failed to get transaction ID from Arweave response. Response: {arw_response}")

                    # Store Pinata reference, upload time, and SHA256 hash
                    references.setdefault("ipfs", {}).setdefault(str(args.size), []).append({
                        "hash": ipfs_hash,
                        "sha256": sha256_hash,
                        "upload_time": pinata_upload_duration,
                        "timestamp": ipfs_timestamp
                    })

                # Save references to JSON file after each upload
                with open(references_file, 'w') as f:
                    json.dump(references, f, indent=4)
            if not continuous:
                break

    if args.download:
        # Read the references from file
        if os.path.exists(references_file):
            with open(references_file, 'r') as f:
                references = json.load(f)
        else:
            logging.error("References file not found. Exiting download.")
            sys.exit(1)

        while True:
            for r in range(repeat_count):

                swarm_tasks = []
                ipfs_tasks = []
                arw_tasks = []

                # Create download tasks for Swarm
                if "swarm" in references:
                    for size, swarm_entries in references["swarm"].items():
                        for entry in swarm_entries:
                            swarmhash = entry["hash"]
                            sha256_hash = entry["sha256"]
                            for url in swarm_dl_servers:
                                task = http_curl(url, swarmhash, sha256_hash, 15, size)
                                swarm_tasks.append(task)

                # Create download tasks for IPFS
                if "ipfs" in references:
                    for size, ipfs_entries in references["ipfs"].items():
                        for entry in ipfs_entries:
                            ipfs_hash = entry["hash"]
                            sha256_hash = entry["sha256"]
                            for url in ipfs_dl_servers:
                                task = http_ipfs(url, ipfs_hash, sha256_hash, 15, size)
                                ipfs_tasks.append(task)

                # Create download tasks for Arweave
                if "arweave" in references:
                    for size, arweave_entries in references["arweave"].items():
                        for entry in arweave_entries:
                            arw_transaction_id = entry["hash"]
                            sha256_hash = entry["sha256"]
                            for url in arw_dl_servers:
                                task = http_arw(url, arw_transaction_id, sha256_hash, 15, size)
                                arw_tasks.append(task)

                # Combine all tasks and run them asynchronously
                all_tasks = arw_tasks + swarm_tasks + ipfs_tasks
                #results = await asyncio.gather(*all_tasks, return_exceptions=True)
                # Run tasks serially and append results
                results = []
                for task in all_tasks:
                    result = await task
                    results.append(result)
            
                # Process the results
                for result in results:
                    if isinstance(result, Exception):
                        print(f"Error downloading: {result}")
                    else:
                        print(f"Download successful: {result}")

                fastest_time = float('inf')
                fastest_server = None
                fastest_storage = None
                fastest_ip = None
                fastest_attempts = 0

                slowest_time = 0
                slowest_server = None
                slowest_storage = None
                slowest_ip = None
                slowest_attempts = 0

                for result in results:
                    if isinstance(result, Exception):
                        logging.error(f'Task failed: {str(result)}')
                    else:                        
                        elapsed_time, sha256sum_output, server_loc, server, ip, attempts, storage, size, reference = result
                        
                        # Create a result dictionary
                        result_dict = {
                            "server": server,
                            "ip": ip,
                            "latitude": server_loc.latitude if server_loc else None,
                            "longitude": server_loc.longitude if server_loc else None,
                            "download_time_seconds": elapsed_time,
                            "sha256_match": sha256sum_output,
                            "attempts": attempts,
                            "size": size,
                            "ref": reference
                        }
                        # Append the result to the corresponding storage list
                        results_by_storage[storage].append(result_dict) 

                        logging.info("-----------------START-----------------------")
                        logging.info(f"size: {size}kb")
                        logging.info(f"{storage} initial download time: {elapsed_time} seconds from {server_loc.city if server_loc else 'Unknown'} - {server} within {attempts} attempts. Size {size} ")

                        if sha256sum_output == 'true':
                            logging.info("SHA256 hashes match.")
                            DL_TIME.labels(storage=storage, server=server, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(elapsed_time)
                            DL_TIME_SUM.labels(storage=storage, server=server, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).observe(elapsed_time)
                        else:
                            logging.info("SHA256 hashes do !NOT! match.")
                            NO_MATCH.labels(storage=storage, server=server, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).inc()
                        logging.info("-----------------END-------------------------")

                        if elapsed_time < fastest_time:
                            fastest_time = elapsed_time
                            fastest_server = server
                            fastest_storage = storage
                            fastest_ip = ip
                            fastest_attempts = attempts

                        if elapsed_time > slowest_time:
                            slowest_time = elapsed_time
                            slowest_server = server
                            slowest_storage = storage
                            slowest_ip = ip
                            slowest_attempts = attempts

                        #push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)
                logging.info("-----------------SUMMARY START-----------------------")
                logging.info(f"Fastest time: {fastest_time} for server {fastest_server} and IP {fastest_ip} with {fastest_attempts} attempts")
                logging.info(f"Slowest time: {slowest_time} for server {slowest_server} and IP {slowest_ip} with {slowest_attempts} attempts")
                DL_TIME_EXTREMES.labels(storage=fastest_storage, server=server, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(fastest_time)
                DL_TIME_EXTREMES.labels(storage=slowest_storage, server=server, latitude=server_loc.latitude, longitude=server_loc.longitude, size=size).set(slowest_time)

                logging.info("-----------------SUMMARY END-------------------------")

            push_to_gateway(prometheus_gw, job=job_label, registry=registry, handler=pgw_auth_handler)
            for storage, storage_results in results_by_storage.items():
                logging.info(f"Results for {storage}:")
                for result in storage_results:
                    logging.info(result)
        
                # Save the results to the JSON file
                save_test_results([
                    {
                        "timestamp": datetime.datetime.now(pytz.utc).isoformat(),
                        "size_kb": size,
                        "storage": storage,
                        "results": storage_results
                    }
                ])

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
    parser.add_argument('--repeat', type=int, help='Number of times to repeat the upload process', default=1)
    parser.add_argument('--continuous', action='store_true', help='Continuously upload chunks (overrides --repeat)')
    parser.add_argument('--upload', action='store_true', help='Upload')
    parser.add_argument('--gateway', action='store_true', help='Gateways Download')
    parser.add_argument('--download', action='store_true', help='Download')

    args = parser.parse_args()
    signal.signal(signal.SIGINT, signal_handler)
    asyncio.run(main(args))


