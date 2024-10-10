import subprocess
import os


# Function to generate a random file using `dd` command
def generate_random_file_dd(size, replicate_id):
    file_name = f"file_{size}_rep_{replicate_id}.dat"
    file_path = os.path.join("generated_files", file_name)
    os.makedirs("generated_files", exist_ok=True)  # Ensure directory exists
    
    # Convert size to dd format (e.g., 1KB -> 1k, 10MB -> 10M)
    size_map = {
        "1KB": "1k",
        "10KB": "10k",
        "100KB": "100k",
        "1MB": "1M",
        "10MB": "10M"
    }
    
    dd_size = size_map[size]
    
    # Call dd command to generate the file
    command = f"dd if=/dev/urandom of={file_path} bs={dd_size} count=1"
    
    print(f"Generating file: {file_name} with size {size}")
    subprocess.run(command, shell=True, check=True)


# Example usage for generating all files
def generate_all_files_dd(file_sizes, replicates):
    for file_size in file_sizes:
        for replicate_id in range(1, replicates + 1):
            generate_random_file_dd(file_size, replicate_id)


# Example call
file_sizes = ["1KB", "10KB", "100KB", "1MB", "10MB"]
replicates = 30
generate_all_files_dd(file_sizes, replicates)
