import itertools
import os


# Define all experimental factors:
sizes = ["1KB", "10KB", "100KB", "1MB", "10MB"]
platforms = ["Swarm", "Arweave", "Ipfs"]
servers = ["Server1", "Server2", "Server3", "Server4"]
modes = ["Node", "Gateway"]
replicates = range(1, 31) # Or whatever the maximum number of replicates should be

# Create cross-table with all combinations of file size and replicate number; will be
# used for generating files:
xtab_files = list(itertools.product(sizes, replicates))

# Create cross-table with all possible factor combinations; will be used for running
# the experiment:
xtab_experiment = list(itertools.product(sizes, platforms, servers, modes, replicates))


# Generate the random files that we'll be uploading later:
for (file_size, replicate_id) in xtab_files:
    # Implement using dd. It would also be good to make the generation pseudo-random,
    # based on some random seed, so that we have full control over replicatbility:
    generate_random_file(file_size, replicate_id)


# Run the experiment for each possible parameter combination:
for (file_size, platform, server, mode, replicate_id) in xtab_experiment:
    file_name = f"testfile_size-{file_size}_rep-{replicate_id}.dat"
    # Assuming that upload_file_to_platform also returns (1) a unique upload ID,
    # and (2) a log of the time it took to upload etc.:
    upload_id, upload_log = upload_file_to_platform(file_path, platform)
    # Download file and put download time etc. in a log:
    download_log = download_file_from_platform(upload_id, platform, server, mode)
    # Save results in a log:
    log_results(file_size, platform, server, mode, replicate_id, upload_log, download_log)
