class MovingAverage:
    def __init__(self) -> None:
        self.sum = 0
        self.count = 0
    
    def update(self, x):
        self.sum += x
        self.count += 1
        return self.sum / self.count
    
    def get(self):
        return self.sum / self.count