from gabor_tracker import GaborTracker

import sys
import time

import cv2
import torch
import numpy as np
from scipy.io import loadmat
import tqdm
from norfair.metrics import PredictionsTextFile

dev = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
torch.set_grad_enabled(False)
print("using", dev, file=sys.stderr)


# read filters as matlab exports from Filters/
filters = torch.zeros((32,7,9,9),device=dev)
for i in range(0, 4):
    for j in range(0, 8):
        gf = loadmat(f'Filters/filter_{i+1}_{j+1}.mat')['tmp997']
        idx = i * 8 + j
        gft = np.expand_dims(np.moveaxis(gf, 2, 0), axis=0)
        filters[idx] = torch.tensor(gft, device=dev)

# normalize filters to 6-bit int
filters = filters * (31 / torch.max(filters))
filters = filters.float()
# flip the filters so we are doing convolution instead of correlation
filters = filters.flip(2).flip(3)

pol = np.fromfile("spikePolsI8.bin", dtype=np.int8)
# convert boolean event representation to +1/-1 for pos/neg events
pol = pol * 2 - 1
ts = np.fromfile("birds/spikeTsU64.bin", dtype=np.uint64)
x = np.fromfile("birds/spikeXsU16.bin", dtype=np.uint16)
y = np.fromfile("birds/spikeYsU16.bin", dtype=np.uint16)

dt = 2e3
idx = 0
t = ts[idx]

gaborTracker = GaborTracker(filters, 8.0, max(y), max(x))

# preallocate tensor to store current frame
curr_frame = torch.zeros((max(y), max(x)), device=dev)

video = cv2.VideoWriter('birds.avi',
                        cv2.VideoWriter_fourcc(*'MJPG'), 22, (max(x)*2, max(y)))
outfile = PredictionsTextFile("birds-mot1.1-trimmed")
start_time = time.time()
frames = 0

with tqdm.tqdm(total=int(outfile.length)) as pbar:
    while idx < len(ts):
        start = time.time_ns()
        t = ts[idx]

        # we read events on CPU and then copy to GPU
        curr_frame_np = np.zeros(curr_frame.shape, dtype=np.float32)
        prev_idx = idx

        # read events until we reach t + dt
        while idx < len(ts) and ts[idx] < t + dt:
            curr_frame_np[y[idx]-1, x[idx]-1] += pol[idx]
            idx += 1
        prev_idx = idx

        # copy frames we read to GPU
        curr_frame = torch.tensor(curr_frame_np, device=dev)
        curr_frame = torch.clamp(curr_frame, min=-1, max=1)

        # give frame to tracker
        out = gaborTracker.update(curr_frame)
        video.write(out)
        # the true frame number takes into account the window of 55 frames proccesed
        outfile.update(gaborTracker.tracked_objects, frame_number=(frames-((55)//2))+1)

        frames += 1
        pbar.update(1)

        if outfile.text_file.closed:
            break
        cv2.imshow("frame", out)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

video.release()
cv2.destroyAllWindows()

gaborTracker.print_times()
