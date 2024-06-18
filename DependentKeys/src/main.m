#import <Foundation/Foundation.h>
#import <time.h>

@interface Layer : NSObject
@property (nonatomic, strong) Layer *subLayer;
@property (nonatomic) NSInteger layer;

@end

@implementation Layer

+ (instancetype)createLayerTree:(NSInteger)depth {
    Layer *root = [[Layer alloc] initWithLayer:0];
    Layer *current = root;
    for (NSInteger i = 1; i < depth; i++) {
        Layer *next = [[Layer alloc] initWithLayer:i];
        current.subLayer = next;
        current = next;
        [next release];
    }
    return root;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.layer = 0;
    }
    return self;
}

- (instancetype)initWithLayer:(NSInteger)layer {
    self = [super init];
    if (self) {
        _layer = layer;
    }
    return self;
}

+ (NSSet *)keyPathsForValuesAffectingDescription {
    return [NSSet setWithObjects:@"subLayer.description", @"layer", nil];
}

- (NSString *)description {
    return [NSString
        stringWithFormat:@"Layer %ld: %@", _layer, [_subLayer description]];
}

- (void)dealloc {
    // NSLog(@"Layer %ld dealloc", _layer);
    [_subLayer release];
    [super dealloc];
}

@end

static NSInteger observerCallbackCount = 0;

@interface Observer : NSObject
@end

@implementation Observer
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    observerCallbackCount++;
}

@end

static NSInteger intervalToMilliseconds(struct timespec start,
                                        struct timespec end) {
    long seconds = end.tv_sec - start.tv_sec;
    long nanoseconds = end.tv_nsec - start.tv_nsec;
    return (seconds * 1000) + (nanoseconds / 1000000);
}

static void benchmarkDependentKeys(NSInteger depth, NSInteger updates) {
    @autoreleasepool {
        Layer *root = [Layer createLayerTree:depth];
        Layer *next = [[Layer alloc] initWithLayer:depth];
        Observer *observer = [[Observer alloc] init];

        struct timespec start, end;
        NSInteger milliseconds;

        [root addObserver:observer
               forKeyPath:@"description"
                  options:NSKeyValueObservingOptionNew |
                          NSKeyValueObservingOptionOld
                  context:NULL];

        Layer *current = root;
        while (current.subLayer) {
            current = current.subLayer;
        }

        clock_gettime(CLOCK_MONOTONIC, &start);
        [current setSubLayer:next];
        for (NSInteger i = 1; i <= updates; i++) {
            [next setLayer:depth + i];
        }
        clock_gettime(CLOCK_MONOTONIC, &end);

        milliseconds = intervalToMilliseconds(start, end);

        printf("%ld,%ld,%ld,%ld\n", depth, updates + 1,
               (long)observerCallbackCount, (long)milliseconds);

        observerCallbackCount = 0;

        [root removeObserver:observer forKeyPath:@"description"];

        [root release];
        [next release];
        [observer release];
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        printf("Depth,Updates,Observer Callbacks,Time (ms)\n");
        for (NSInteger i = 800; i <= 900; i += 10) {
            for (NSInteger j = 45; j <= 50; j += 1) {
                benchmarkDependentKeys(i, j);
            }
        }
    }
    return 0;
}