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



### Getting Started with Running the Experiment

1. Ensure you have Python 3 installed on your system.
2. Clone this repository to your local machine.
3. Install the required Python dependencies using `pip install -r requirements.txt`.
4. Configure the script by modifying the `config.json` file and setting environment variables as needed.
5. Run the script using the appropriate command-line arguments to perform upload and testing tasks.

Simple usage:

```bash
bash runswarm.sh
```



### Organization and Data Analysis Workflow

Results are always assembled in the `data` directory, in a subdirectory labelled with the name of the platform (nowadays we are just focusing on Swarm instead of Arweave and IPFS) and the date of the experiment. For example, the run that was made to test the Swarm 2.6 release belongs in `/data/swarm-2025-07`. The raw data that any such subdirectory should contain are as follows:
 
- A short configuration file called `config.json`. *These might contain sensitive information and are therefore never uploaded to the repo.* In case you need the config file, ask Marko Zidaric to send it to you, and place it in the appropriate subdirectory. (It is on the `.gitignore` list, so it will never be pushed.)
- A large JSON file called `results_onlyswarm.json`. (The "onlyswarm" refers to the fact that it does not collect data from IPFS and Arweave, although by now that's the default behaviour anyway.) This contains all the measured data on download speeds.
- A directory called `references`, containing a larger batch of small JSON files. These files will have names like `references_onlyswarm_0_0_2025-07-28_18-15.json` and similar. They contain the measurements on upload speeds.

Make sure that after any one run of the experiment, things are set up as described above. Then do the following. First, the directory `analysis-code` contains a file called `compile-data.R`. This can be run from the command line, like this:

```bash
Rscript compile-data.R ../data/swarm-2025-07/
```

This assumes that the call is executed from within the `analysis-code` subdirectory. (If it isn't, change the path accordingly.) It also assumes that we are working with the data in `swarm-2025-07`, which should also be changed to the folder which contains the data that we actually want to analyze. Also, for the above call to work, be sure to have `Rscript` installed, which is a command line tool for R (it comes with the R suite, so installing R will also install `Rscript`). Note: the above is robust to leaving off the trailing slash, so `Rscript compile-data.R ../data/swarm-2025-07` will also work.

Running the above will create a data file called `swarm.rds` in the same subdirectory that is specified in the command line call (for our example: at `../data/swarm-2025-07/swarm.rds`). This is a data file in compressed form that R can read natively. It contains all the information on download data in tidy tabular format. Apart from creating this file, the script will also display a bunch of information in the console screen. This gives a quick overview of how many download failures there have been, and other similar information on data integrity.

To recap: if all went well, the subdirectory of the experiment should now contain (i) the `config.json` file; (ii) the `results_onlyswarm.json` file; (iii) the `references` sub-subdirectory with a bunch of files holding upload speed data; and (iv) the `swarm.rds` file with the tidy, processed and cleaned data generated from `results_onlyswarm.json`.

This is the point where serious data analysis can begin. To play around with various options and to try things out before deciding on including them in an official report, the `analysis-code` directory has to R scripts:

- `download-times.R`: For analyzing and visualizing download times.
- `upload-times.R`: The same, but for upload times instead of download times.

To see an actual example of a report and the R code it relies on, check out e.g. `/data/swarm-2025-07/report.qmd`. The `qmd` extension stands for "Quarto Markdown". It is a dialect of Markdown that allows one to include R code chunks, have them executed in the background, and include their output as tables or figures in the final document (which is a corresponding `report.pdf` file). Note: for any `qmd` file, always assume that your working directory is wherever the `qmd` file resides, so adjust paths accordingly.

For future reports: feel free to copy the earlier `report.qmd` and to adjust it slightly to suit your new needs.
