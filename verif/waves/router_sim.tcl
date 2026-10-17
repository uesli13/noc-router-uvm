# Simulator command file: databases, probes, launch SimVision layout
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_top -all -depth all
simvision -input ../waves/router_waves.svcf