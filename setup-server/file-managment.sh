# set permission read/write for all uid to the data and folder/files insider the data; use for set permission for volume mount; suitable for dev/test; should set permission for specifc userid; it will be safer
sudo chmod -R 1777 ./data

# disk size check
du -sh *