# Web3 Storage Benchmarking Experiment


### Experimental design

The purpose of this project is to compare data download speeds and reliability across various Web3 storage platforms. We are currently focusing on three such platforms: IPFS, Swarm, and Arweave. The idea is to first upload files of various sizes to all three platforms, and then to download them under different circumstances. Then, one can compare the times needed for data retrieval and see if some platforms allow quicker downloads than others.

We want to implement the speed comparison as a proper, repeatable, well-designed digital experiment. In the experiment, we upload random data with fixed size first, and later retrieve them, measuring download speeds. The following factors should be varied in the experiment, in a fully factorial way:^[With some exceptions, to be detailed later.]

- `size_kb`: The size of the uploaded random file, in kilobytes. Importantly, every single upload should be with a unique random file, even if the file size is otherwise equal. The 6 distinct factor levels of file size are: 1KB, 10KB, 100KB, 1MB, 10MB, and 100MB.
- `platform`: Whether the target platform is IPFS, Swarm, or Arweave. Additionally, Swarm itself breaks up into several factors depending on:
  - the strength of erasure coding employed (`0` = None, `1` = Medium, `2` = Strong, `3` = Insane, and `4` = Paranoid);
  - whether there is a checkbook enabled to fund bandwidth incentives (`cb`) or there is no checkbook (`ncb`), although for now we are focusing solely on the `cb` option;
  - the used redundancy strategy (out of all possibilities, we only use `NONE` and `RACE`). 

  Taken together, these lead to 11 distinct factor levels for `platform`, namely `IPFS`, `Arweave`, and all combinations of the above for Swarm: `Swarm_0_cb_NONE`, `Swarm_1_cb_NONE`, `Swarm_2_cb_NONE`, `Swarm_3_cb_NONE`, `Swarm_4_cb_NONE`, `Swarm_0_cb_RACE`, `Swarm_1_cb_RACE`, `Swarm_2_cb_RACE`, `Swarm_3_cb_RACE`, and `Swarm_4_cb_RACE`. (Note: eventually we might also have `nbc`-variants of all these, like `Swarm_0_ncb_NONE`, etc. For now we are not dealing with the checkbook though.)
- `server`: The identity of the server initiating the downloads might influence download speeds. So a single server should be used for the experiment. If more than one server is used, then the experiment as a whole, with all other factors, should be repeated wholesale on the other server(s), and server identity should therefore be an extra experimental factor. So this is a factor with as many distinct levels as the number of servers used.
- `replicate`: To gain sufficient sample sizes for a proper statistical analysis, every single combination of the above factors should be replicated 30 times.

Assuming a single server, the above design leads to (6 filesizes) x (11 platforms) x (1 server) x (30 replicates) = 1980 unique download experiments. For *x* servers, we have 1980*x* experiments. So for 3 servers, that is 5940 measured downloads.


### Notes and remarks on the design

Here are some notes and further points to keep in mind about the experimental design outlined above:

- For Swarm (and only Swarm), upload speeds should also be measured. To do so, one can rely on the tags API to make sure that all chunks have been properly placed and uploaded to the system. When all chunks are placed, that is when upload has properly ended.
- Every download should be performed twice in a row. This is because the second download will then happen in the presence of caching (if supported by the target platform). So this way we are testing download speeds both with- and without caching. We of course expect downloads to be much faster with caching.
- Downloading should not start until after the system has properly stored the data. Since our files are relatively small, uploading should be done in about 10-20 minutes at most. So one crude but reliable way of doing the downloads is to wait exactly 2 hours after every upload, and only then begin downloading. This ought to be more than enough time so that syncing issues are not a problem.
- When testing IPFS, the data should be uploaded from one server but downloaded from another.


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
bash run.sh
```
