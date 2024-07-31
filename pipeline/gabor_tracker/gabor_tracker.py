import numpy as np

import torch
import torch.nn.functional as F
import torchvision.transforms.functional as TF

import cv2
import norfair

from .processing import process_filter, get_components_dbscan, print_times as print_processing_times

from concurrent import futures
import os

import ensemble_boxes
from .utils import MovingAverage
import time


dev = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
torch.set_grad_enabled(False)


def push_to_tensor(tensor, x):
    return torch.cat((x[None], tensor[:-1]))


def normalize(x):
    if x.max() == x.min():
        return x * 0
    return (x - x.min()) / (x.max() - x.min())


def draw_boxes(frame, boxes, scores):
    for box, score in zip(boxes, scores):
        if score > 0:
            frame = cv2.rectangle(
                frame, box[0:2], box[2:4], (0, 255, 0), 1)


def format_detections(boxes, scores):
    norfair_detections = []
    for box, score in zip(boxes, scores):
        if score > 0:
            norfair_detections.append(
                norfair.Detection(
                    np.array([box[0:2], box[2:4]]), np.array([score, score]))
            )
    return norfair_detections


class GaborTracker:
    def __init__(self, filters, gabor_threshold, width, height, column_max = False, use_filt_max = True):
        self.filters = filters
        self.event_frame = torch.zeros((55, width, height), device=dev)
        self.tracker = norfair.Tracker(
            distance_function='euclidean', distance_threshold=40, hit_counter_max=30, initialization_delay=3)
        self.threadpool = futures.ThreadPoolExecutor(
            max_workers=os.cpu_count())
        self.gabor_threshold = gabor_threshold
        self.column_max = column_max
        self.use_filt_max = use_filt_max

        self.conv_time = MovingAverage()
        self.tracker_time = MovingAverage()


    def getGaborFilterValue(self, frames):
        full_frame = F.conv2d(frames, self.filters, stride=1, padding='same')
        if not self.column_max:
            return full_frame

        # keep column maxes of each 64x64 tile in the frame and zero the rest
        for i in range(0, full_frame.shape[2], 64):
            for j in range(0, full_frame.shape[3], 64):
                i_t = min(i + 64, full_frame.shape[2])
                j_t = min(j + 64, full_frame.shape[3])

                window = full_frame[:, :, i:i_t, j:j_t]
                maxes = window.max(dim=3, keepdim=True)[0]
                full_frame[:, :, i:i_t, j:j_t] = window * (window == maxes)
        return full_frame



    def update(self, curr_frame):
        self.event_frame = push_to_tensor(
            self.event_frame, curr_frame)

        gaborValues = torch.tensor([], device=dev)
        # this will only use the middle 7 frames. add to this array to process
        # more frames depending on the object speed. this will result in more
        # convolutions
        intervals = [1]
        t = 0
        for interval in intervals:
            start = time.time_ns()
            interval_gv = self.getGaborFilterValue(
                self.event_frame[(55//2) - ((7//2)*interval)::interval][0:7][None])
            t += time.time_ns() - start
            gaborValues = torch.cat((gaborValues, interval_gv), dim=1)
        self.conv_time.update(t)

        gaborValues = TF.gaussian_blur(gaborValues, [7, 7], [3, 3])

        # for each pixel, take the max gabor value across all filters
        gaborValues_max = torch.clamp(torch.amax(gaborValues, dim=1), min=0)
        gaborValues_max = gaborValues_max[0].cpu().numpy()

        # for visualization, renorm gabor values to 255 b/w frame
        gaborPreview = gaborValues_max.copy()
        maxGabor = np.max(gaborPreview)
        gaborPreview[gaborPreview < self.gabor_threshold] = 0
        gaborPreview = (normalize(gaborPreview) * 255).astype(np.uint8)
        frame = np.array(np.dstack([gaborPreview] * 3))

        if self.use_filt_max:
            boxes, scores = process_filter(
                gaborValues_max, get_components_dbscan, thresh=self.gabor_threshold)
        else:
            gv_list = list(gaborValues[0].cpu().numpy())
            boxes, scores, labels = [], [], []

            def process_helper(inp):
                return process_filter(inp, get_components_dbscan, thresh=self.gabor_threshold)

            for boxes_filt, scores_filt in self.threadpool.map(process_helper, gv_list):
                boxes.append(boxes_filt)
                scores.append([s / maxGabor for s in scores_filt])
                labels.append([1] * len(boxes_filt))
            boxes, scores, labels = ensemble_boxes.weighted_boxes_fusion(
                boxes, scores, labels)

        # boxes are represented as fractions of the image, convert back to pixel
        # coordinates
        denorm_boxes = []
        for box in boxes:
            denorm_boxes.append(np.array([box[0] * frame.shape[1], box[1] * frame.shape[0],
                                          box[2] * frame.shape[1], box[3] * frame.shape[0]]).astype(int))

        start = time.time_ns()
        # feed detections to norfair tracker
        self.tracked_objects = self.tracker.update(
            format_detections(denorm_boxes, scores))
        self.tracker_time.update(time.time_ns() - start)

        # normalize frame to 8-bit b/w rgb
        # 0: negative event
        # 127: no event
        # 128: positive event
        curr_frame_np = self.event_frame[self.event_frame.shape[0] //
                                         2].cpu().numpy()
        curr_frame_np = ((np.clip(curr_frame_np, -1, 1)+1) * 127).astype(np.uint8)
        raw_events = np.dstack([curr_frame_np] * 3)

        # draw tracks on frame
        draw_boxes(frame, denorm_boxes, scores)
        norfair.draw_tracked_boxes(
            raw_events, self.tracked_objects, id_size=0.3, id_thickness=1)

        # preview is events and tracks overlaid on frame
        return np.hstack([raw_events, frame.astype(np.uint8)])

    def print_times(self):
        print("Conv Time", self.conv_time.get())
        print("Tracker Time", self.tracker_time.get())
        print_processing_times()
