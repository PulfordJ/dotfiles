main = {
  type = "disk";
  device = "/dev/nvme1n1";
  content = {
    type = "gpt";
    partitions = {
      ESP = {
        size = "512M";
        type = "EF00";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [
            "defaults"
          ];
          label = "boot";
        };
      };
      swap = {
        size = "8G";
        content = {
          type = "swap";
          randomEncryption = true;
        };
      };
      root = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
          mountOptions = [
            "defaults"
          ];
          label = "nixos";
        };
      };
    };
  };
};
