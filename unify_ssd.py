#!/usr/bin/env python3
import os
import sys
import subprocess
import time

def run_cmd(cmd, check=True):
    print(f"--> Executing: {cmd}")
    # Escape single quotes inside cmd
    safe_cmd = cmd.replace("'", "'\\''")
    full_cmd = f"sudo sh -c '{safe_cmd}'"
    proc = subprocess.run(full_cmd, shell=True, text=True, capture_output=True)
    if proc.returncode != 0 and check:
        print(f"❌ Error (exit {proc.returncode}):\n{proc.stderr}")
        sys.exit(proc.returncode)
    else:
        if proc.stdout.strip():
            print(proc.stdout.strip())
    return proc

def main():
    print("=== UNIFYING SSD PARTITIONS TO SINGLE 237 GB ROOT PARTITION ===")
    
    # 1. Verify current partitions
    res = subprocess.run("lsblk -n -o NAME,MOUNTPOINT | grep 'nvme0n1p3'", shell=True, capture_output=True, text=True)
    if "p3" not in res.stdout and "/home" not in res.stdout:
        print("nvme0n1p3 is not present or already merged!")
    else:
        print("Found /dev/nvme0n1p3 mounted on /home. Proceeding with migration...")
        
        # 2. Backup /home contents to temporary folder /home_backup on root partition
        print("--> Step 1: Backing up /home to /home_backup on root partition...")
        run_cmd("mkdir -p /home_backup")
        run_cmd("cp -a /home/* /home_backup/")
        
        # 3. Unmount /home
        print("--> Step 2: Unmounting /home (/dev/nvme0n1p3)...")
        run_cmd("umount -l /home", check=False)
        time.sleep(1)
        
        # 4. Remove partition 3 from partition table
        print("--> Step 3: Deleting partition /dev/nvme0n1p3...")
        run_cmd("parted -s /dev/nvme0n1 rm 3")
        
        # 5. Expand partition 2 to take 100% of SSD
        print("--> Step 4: Expanding partition /dev/nvme0n1p2 to 100% of SSD...")
        run_cmd("parted -s /dev/nvme0n1 resizepart 2 100%")
        
        # 6. Inform kernel of partition change
        print("--> Step 5: Informing kernel of partition change (partprobe)...")
        run_cmd("partprobe /dev/nvme0n1", check=False)
        time.sleep(2)
        
        # 7. Online resize of ext4 filesystem on /
        print("--> Step 6: Online growing ext4 filesystem on /dev/nvme0n1p2...")
        run_cmd("resize2fs /dev/nvme0n1p2")
        
        # 8. Restore /home contents from /home_backup
        print("--> Step 7: Restoring /home contents...")
        run_cmd("mkdir -p /home")
        run_cmd("cp -a /home_backup/* /home/")
        run_cmd("rm -rf /home_backup")
        
        # 9. Clean up /etc/fstab
        print("--> Step 8: Removing /home partition entry from /etc/fstab...")
        run_cmd("sed -i '/\\/home/d' /etc/fstab")
        
    print("\n=== VERIFYING NEW DISK LAYOUT ===")
    run_cmd("lsblk")
    run_cmd("df -h /")

if __name__ == "__main__":
    main()
