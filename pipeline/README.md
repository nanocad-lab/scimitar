# NanoCAD Gabor Filter Event Camera Motion Tracking

To install the library, run:
```bash
pip install -e .
```

Then to use the example program with the birds dataset,
run:
```bash
python examples/gabor_visualizer.py
```
Ensure that the birds dataset is present under the path `birds`, and the
`birds-mot1.1-trimmed` path is present in the working directory, or edit the
script accordingly. The tracking results for use with
[TrackEval](https://github.com/JonathonLuiten/TrackEval/tree/master) will be
present in the `predictions/` directory. Refer to the published dataset for
ground truth data/sequence info.

The `GaborTracker` class is provided. This expects event data as accumulated
frames, with each pixel containing a +1 for positive event, -1 for negative
event, and 0 for no event during an accumulation period. For a usage example
with the Birds dataset, see `examples/gabor_visualizer.py`.

In general, your code should appear as,
```python
from gabor_tracker import GaborTracker

tracker = GaborTracker(filters, threshold, image_height, image_width)

# accumulation logic
frame = tracker.update(frame)
# display or save frame (frame is in cv2.UINT8 format)
# iterate over tracker.tracked_objects
```

Filters should be provided as a single PyTorch tensor in `(N x C x H x W)`,
where `N` is the number of filters, and `C` is the number of timechannels. The
`GaborTracker` class is written to expect 7 timechannels, and modifications must
be made if you wish to test with a different number of timechannels.

The `GaborTracker` class also takes two additional arguments, the first is
`column_max`. If this is true, the tracker will preserve only the column maxes
for each filter on each 64x64 "ROI" in the frame.

The second is `use_filt_max`. If this is set to false, the tracker will perform
clustering and detection for each filter in parallel, and then attempt to merge
them into a single set of detections. This will cause a significant increase in
computation time. It is not recommended to turn this flag on, as we have not
seen any benefit from doing so.
