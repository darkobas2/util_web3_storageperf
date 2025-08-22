# Web3 Storage Benchmarking Experiment



### Purpose

The original purpose of this project was to compare data download speeds and reliability across various Web3 storage platforms. We were focusing on three such platforms: IPFS, Swarm, and Arweave. The idea was to first upload files of various sizes to all three platforms, and then to download them under different circumstances. Then, one can compare the times needed for data retrieval and see if some platforms allow quicker downloads than others.

In the meantime the project has evolved, and is currently (as of August 2025) used as a tool to check how new Swarm features affect up- and download speeds. This means that much of the data analysis consists of comparing results from two different runs of the experiment; one without, and one with some feature. Recently, we compared the performance of the 2.5 and 2.6 releases this way, as well as 2.6 with the same release but with PR 5097 enabled.



### Experimental design

Here is a description of the current experimental design, as it stands in August 2025. The purpose is to measure up- and download speeds on Swarm for various file sizes, erasure settings, and retrieval strategies. We vary all parameters in a fully-factorial way, to get at all their possible combinations. The factors are as follows:

- `size`: The size of the uploaded random file. We have 6 distinct factor levels: 1 KB, 10 KB, 100 KB, 1 MB, 10 MB, and 50 MB. Every file has a size that matches one of these values exactly. Importantly, every single upload is a unique random file, even if the file sizes are otherwise equal---this removes the confounding effects of caching.
- `erasure`: The strength of erasure coding. We have five factor levels: `0` (= `NONE`), `1` (= `MEDIUM`), `2` (= `STRONG`), `3` (= `INSANE`), and `4` (= `PARANOID`).
- `strategy`: The retrieval strategy used to download the file. Its value is necessarily `NONE` in the absence of erasure coding---i.e., when `erasure = 0`. Otherwise, it is either `DATA` or `RACE`.
- `server`: The identity of the server initiating the downloads might influence download speeds. For a fair comparison, servers should be identical within an experiment, but it makes sense to perform the whole experimental suite over multiple different servers, to control for server-specific effects. This means that we have an extra experimental factor, with as many distinct levels as the number of distinct servers used. Here we use three distinct servers: `Server 1`, `Server 2`, and `Server 3`.
- `replicate`: To gain sufficient sample sizes for proper statistical analysis, every single combination of the above factors is replicated 30 times. For example, given the unique combination of 1MB files uploaded without erasure coding on Server 1, we actually up- and downloaded at least 30 such files (each being a unique random file).

The above design has (6 file sizes) x (5 erasure code levels) x (3 retrieval strategies) x (3 servers) x (30 replicates). However, the `NONE` retrieval strategy is only ever used when `erasure` is `NONE`, and the `DATA` and `RACE` strategies only when `erasure` is not `NONE`. So the total number of unique download experiments is (30 replicates) x (6 file sizes) x (3 servers) x (1 strategy & erasure level + 2 strategies x 4 erasure levels), or 4860.

Some further notes about the experimental design:

-   All uploads are direct, as opposed to deferred.
-   We need to make sure that no download starts after the system has properly stored the data. Since our files are relatively small, uploading should be done in a few minutes at most (as we will see later, the longest upload in our data took below 3 minutes). So we opted for a crude but reliable way of eliminating any syncing issues: we waited exactly 2 hours after every upload, and began downloading only then.
-   All downloads are done using nodes with an active chequebook.
-   Every download is re-attempted in case of a failure. In total, 15 attempts are made before giving up and declaring that the file cannot be retrieved.



### Dependencies

Running the experiment relies on several Python libraries, including but not limited to:

- `asyncio` for asynchronous I/O operations.
- `aiohttp` for asynchronous HTTP requests.
- `asyncssh` for asynchronous SSH connections.
- `prometheus_client` for collecting and exposing metrics.
- `ipinfo` for retrieving IP geolocation information.
- prometheus push gateway server

Additionally, external tools such as `curl` and `jq` are used for specific tasks.



### Getting Started

1. Ensure you have Python 3 installed on your system.
2. Clone this repository to your local machine.
3. Install the required Python dependencies using `pip install -r requirements.txt`.
4. Configure the script by modifying the `config.json` file and setting environment variables as needed.
5. Run the script using the appropriate command-line arguments to perform upload and testing tasks.



### Usage

```bash
bash runswarm.sh
```
