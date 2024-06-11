# Web3 Storage Speed Test

Web3 Storage Speed Test is a tool designed for testing the speed and reliability of uploading data to distributed storage networks, particularly focused on Swarm and related technologies.

## Overview

Web3 Storage Speed Test is a Python script that utilizes various libraries and APIs to perform the following tasks:

- Generate random JSON data of a specified size.
- Upload the generated data to a specified URL.
- Perform HTTP and SSH requests to retrieve the uploaded data and verify its integrity.
- Measure and record various metrics related to the upload and retrieval process.
- Push metrics to a Prometheus Pushgateway for monitoring and analysis.

## Tests

Test Execution:

Upload:
SWARM: The script uploads the generated data to a Swarm gateway using the upload_file function with a provided URL.
IPFS: It stores the random data generated to a file and uploads to a IPFS node runing on the local machine using the ipfs_api.http_client.add function, storing the resulting CID for later retrieval. Content is pinned and bandwidth is 1000/300Mbps

Retrieval:

The script retrieves the uploaded data from various locations:
 - SSH nodes: It uses SSH connections to access Swarm nodes listed in ssh_servers. It selects a random kubernetes pod running bee and access its api. 
 - HTTP Gateways: It retrieves data from HTTP gateways or http accessible bee nodes listed in http_servers using the http_curl function.
 - IPFS Gateways: It retrieves data from IPFS gateways listed in ipfs_servers using the http_ipfs function. Gateways used are ipfs.io, w3s.link, ipfs.eth.aragon.network, nftstorage.link, cloudflare-ipfs.com
 - IPFS Nodes: Some nodes are prepared with ipfs/ipget tool to fetch the data from the network.

Performance Metrics:

Grafana provides the following metrics which are also explained in the dashboard.
    Distribution time:
    - After the newly generated data is uploaded it tries simultaniously retrieve it from various sources around the globe. Time is measured until a file is retrieved and successfully checked that it matches the uploaded content.
    Gateway metrics:
    - It tries to retrieve the data previously uploaded by the upload (ie. distribution) task from various public gateways. (caching is expected here). Time is measured until a file is retrieved and successfully checked that it matches the uploaded content.

    Download metrics:
    - It tries to retrieve the data previously uploaded by the upload (ie. distribution) task from various swarm nodes or ipfs hosts preinstalled with ipfs/ipget tool. (*TODO: switch to a similar tool for swarm once its available). Time is measured until a file is retrieved and successfully checked that it matches the uploaded content.

Successful Attempt: script tries to download the data and verifies its integrity with sha256. If sha is not matched or a http timeout occours it retries (up to 15 times). cumulative time spent on all retrieval attempts is measured.

SHA256 Hash Match: This verifies if the downloaded data matches the original data uploaded.

## Dependencies

Web3 Storage Speed Test relies on several Python libraries, including but not limited to:

- `asyncio` for asynchronous I/O operations.
- `aiohttp` for asynchronous HTTP requests.
- `asyncssh` for asynchronous SSH connections.
- `prometheus_client` for collecting and exposing metrics.
- `ipinfo` for retrieving IP geolocation information.
- prometheus push gateway server

Additionally, external tools such as `curl` and `jq` are used for specific tasks.

## Getting Started

1. Ensure you have Python 3 installed on your system.
2. Clone this repository to your local machine.
3. Install the required Python dependencies using `pip install -r requirements.txt`.
4. Configure the script by modifying the `config.json` file and setting environment variables as needed.
5. Run the script using the appropriate command-line arguments to perform upload and testing tasks.

## Usage

```bash
bash run.sh
```
