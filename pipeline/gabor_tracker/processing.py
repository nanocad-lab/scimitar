import numpy as np
from scipy.ndimage.filters import maximum_filter
from scipy.ndimage.morphology import generate_binary_structure, binary_erosion
import sklearn.cluster

from .utils import MovingAverage
import time

def detect_peaks(image):
    neighborhood = generate_binary_structure(2, 2)
    local_max = maximum_filter(image, footprint=neighborhood) == image
    background = (image == 0)
    eroded_background = binary_erosion(
        background, structure=neighborhood, border_value=1)
    detected_peaks = local_max ^ eroded_background
    return detected_peaks


def get_components_dfs(frame, init_mask, thresh=0.2, high_thresh=0.6):
    # perform dfs on the frame starting at points where init_mask is true
    # and return the connected components
    # init_mask is a boolean array of the same shape as frame
    # frame is a 2d array of floats
    # returns a list of connected components, each of which is a list of
    # (x, y) tuples
    # https://stackoverflow.com/questions/44865023/connected-components-in-a-2d-numpy-array
    # https://stackoverflow.com/questions/44865023/connected-components-in-a-2d-numpy-array/44865974#44865974
    # https://stackoverflow.com/questions/44865023/connected-components-in-a-2d-numpy-array/44865974#44865974

    # create a mask of the frame where the init_mask is true
    # and the rest is false
    frame[frame < thresh] = 0
    peakfind_frame = frame.copy()
    peakfind_frame[peakfind_frame < high_thresh] = 0
    init_mask = detect_peaks(peakfind_frame)
    if np.count_nonzero(init_mask) == 0:
        return []
    mask = frame.astype(np.bool)
    # create a list of connected components
    components = []
    # while there are still points in the mask
    for start in np.argwhere(init_mask):
        # create a stack of points to visit
        stack = [start]
        # create a list of points in the connected component
        component = []
        maxGabor = 0
        # while there are still points to visit
        while stack:
            # pop the next point off the stack
            point = stack.pop()
            if point[0] < 0 or point[0] >= mask.shape[0] or point[1] < 0 or point[1] >= mask.shape[1]:
                continue
            # if the point is in the mask
            if mask[point[0], point[1]]:
                # add the point to the component
                maxGabor = max(maxGabor, frame[point[0], point[1]])
                component.append(point)
                # remove the point from the mask
                mask[point[0], point[1]] = False
                # add the neighbors of the point to the stack
                stack.extend([
                    [point[0] - 1, point[1]],
                    [point[0] + 1, point[1]],
                    [point[0], point[1] - 1],
                    [point[0], point[1] + 1],
                ])
        if component:
            components.append({"points": component, "maxGabor": maxGabor})

    return components


def get_components_dbscan(frame, thresh=0.2):
    # get list of nonzero coordinates in frame
    nonzero = np.argwhere(frame > thresh)
    # if there are no nonzero coordinates, return empty list
    if len(nonzero) < 2:
        return []
    # create a dbscan clustering object
    db = sklearn.cluster.DBSCAN(eps=3, min_samples=15)
    # db = sklearn.cluster.MeanShift(bandwidth=15, cluster_all=False)
    # db = sklearn.cluster.SpectralClustering()
    # db = sklearn.cluster.OPTICS(max_eps=5, min_samples=10)
    # db = sklearn.cluster.AgglomerativeClustering(n_clusters=None, distance_threshold=5)
    # fit the dbscan clustering object to the nonzero coordinates
    db.fit(nonzero)
    # get the labels of the clusters
    labels = db.labels_
    # get the number of clusters
    n_clusters_ = len(set(labels)) - (1 if -1 in labels else 0)
    # create a list of clusters
    clusters = []
    # for each cluster
    for i in range(n_clusters_):
        # get the indices of the points in the cluster
        cluster_indices = np.argwhere(labels == i)
        # get the points in the cluster
        cluster_points = [nonzero[idx[0]] for idx in cluster_indices]
        # add the points in the cluster to the list of clusters
        clusters.append({"points": cluster_points, "maxGabor": np.max(
            [frame[p[0], p[1]] for p in cluster_points])})
    return clusters

cluster_time = MovingAverage()
boxes_time = MovingAverage()

def process_filter(filter, method, **kwargs):
    """
    filter_highthresh = filter.copy()
    filter_highthresh[filter_highthresh < high_thresh] = 0
    peaks = detect_peaks(filter_highthresh)
    if len(peaks) == 0:
        return [], []
    """
    # components = run_dfs(filter, peaks)
    start = time.time_ns()
    components = method(filter, **kwargs)
    cluster_time.update(time.time_ns() - start)
    bounding_boxes = []
    scores = []
    start = time.time_ns()
    for component in components:
        x = [(p[1] / filter.shape[1]) for p in component["points"]]
        y = [(p[0] / filter.shape[0]) for p in component["points"]]
        bounding_boxes.append([min(x), min(y), max(x), max(y)])
        scores.append(component["maxGabor"])
    boxes_time.update(time.time_ns() - start)
    return bounding_boxes, scores

def print_times():
    print("Cluster Time", cluster_time.get())
    print("Boxes Time", boxes_time.get())
