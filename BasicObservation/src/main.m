#include "Foundation/NSKeyValueObserving.h"
#include "Foundation/NSObjCRuntime.h"
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <time.h>

static NSInteger observerCallbackCount = 0;

@interface TestObject1 : NSObject
@property (nonatomic, strong) NSString *string;
@end

@implementation TestObject1
@end

@interface TestObject2 : NSObject
@property (nonatomic) NSInteger number;
@end

@implementation TestObject2
@end

/* We access the array via mutableArrayValueForKey:.
 * Note that no setter function is defined for the array property,
 * so the KVO machinery will have to go through the get/mutate/set codepath.
 */
@interface TestKVCMediatedArray : NSObject {
    NSMutableArray *_kvcMediatedArray;
}
@end
@implementation TestKVCMediatedArray

- (instancetype)init {
    self = [super init];
    if (self) {
        _kvcMediatedArray = [NSMutableArray new];
    }
    return self;
}

@end

/* Indirect proxy (add<key>Object, etc.) benchmarking.
 */
@interface TestProxySet : NSObject {
    NSMutableSet *_set;
}
@end

@implementation TestProxySet

- (instancetype)init {
    self = [super init];
    if (self) {
        _set = [NSMutableSet new];
    }
    return self;
}

- (NSSet *)proxySet {
    return _set;
}

- (void)addProxySetObject:(id)obj {
    [_set addObject:obj];
}

- (void)removeProxySetObject:(id)obj {
    [_set removeObject:obj];
}

- (void)addProxySet:(NSSet *)set {
    [_set unionSet:set];
}

- (void)removeProxySet:(NSSet *)set {
    [_set minusSet:set];
}

@end

@interface TestProxyArray : NSObject {
    NSMutableArray *_array;
}

@end

@implementation TestProxyArray

- (instancetype)init {
    self = [super init];
    if (self) {
        _array = [NSMutableArray new];
    }
    return self;
}

- (NSArray *)proxyArray {
    return _array;
}

- (void)insertObject:(id)obj inProxyArrayAtIndex:(NSUInteger)index {
    [_array insertObject:obj atIndex:index];
}

- (void)removeObjectFromProxyArrayAtIndex:(NSUInteger)index {
    [_array removeObjectAtIndex:index];
}

- (void)insertProxyArray:(NSArray *)array atIndexes:(NSIndexSet *)indexes {
    [_array insertObjects:array atIndexes:indexes];
}

- (void)removeProxyArrayAtIndexes:(NSIndexSet *)indexes {
    [_array removeObjectsAtIndexes:indexes];
}

- (void)replaceObjectInProxyArrayAtIndex:(NSUInteger)index withObject:(id)obj {
    [_array replaceObjectAtIndex:index withObject:obj];
}

- (void)replaceProxyArrayAtIndexes:(NSIndexSet *)indexes
                    withProxyArray:(NSArray *)array {
    [_array replaceObjectsAtIndexes:indexes withObjects:array];
}

@end

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

// Output as csv row
// name,iterations,callbackCount,milliseconds
#define BENCHMARK_PROPERTY_OBSERVATION(name, options, startInterval,           \
                                       endInterval, step, stmt)                \
    do {                                                                       \
        struct timespec start, end;                                            \
        NSInteger milliseconds;                                                \
        for (NSInteger iterations = startInterval; iterations <= endInterval;  \
             iterations += step) {                                             \
            clock_gettime(CLOCK_MONOTONIC, &start);                            \
            for (NSInteger i = 0; i < iterations; i++) {                       \
                stmt;                                                          \
            }                                                                  \
            clock_gettime(CLOCK_MONOTONIC, &end);                              \
            milliseconds = intervalToMilliseconds(start, end);                 \
            printf("%s,%ld,%ld,%ld,%ld\n", name, options, (long)iterations,    \
                   observerCallbackCount, (long)milliseconds);                 \
                                                                               \
            observerCallbackCount = 0;                                         \
        }                                                                      \
    } while (0)

static NSInteger intervalToMilliseconds(struct timespec start,
                                        struct timespec end) {
    long seconds = end.tv_sec - start.tv_sec;
    long nanoseconds = end.tv_nsec - start.tv_nsec;
    return (seconds * 1000) + (nanoseconds / 1000000);
}

/* Observe the string property of object */
static void benchmarkStringPropertyObservation(NSInteger startIterations,
                                               NSInteger endIterations,
                                               NSInteger step,
                                               NSInteger options) {
    @autoreleasepool {
        TestObject1 *object = [TestObject1 new];
        Observer *observer = [Observer new];
        SEL setStringSelector = NSSelectorFromString(@"setString:");

        [object addObserver:observer
                 forKeyPath:@"string"
                    options:options
                    context:NULL];

        BENCHMARK_PROPERTY_OBSERVATION(
            "NSString Property Observation (nonatomic)", options,
            startIterations, endIterations, step,
            ((void (*)(id, SEL, NSString *))objc_msgSend)(
                object, setStringSelector, @"Hello, World!"));

        [object removeObserver:observer forKeyPath:@"string"];

        [object release];
        [observer release];
    }
}

static void benchmarkNumberPropertyObservation(NSInteger startIterations,
                                               NSInteger endIterations,
                                               NSInteger step,
                                               NSInteger options) {
    @autoreleasepool {
        TestObject2 *object = [TestObject2 new];
        Observer *observer = [Observer new];
        SEL setNumberSelector = NSSelectorFromString(@"setNumber:");

        [object addObserver:observer
                 forKeyPath:@"number"
                    options:options
                    context:NULL];

        BENCHMARK_PROPERTY_OBSERVATION(
            "NSInteger Property Observation (nonatomic)", options,
            startIterations, endIterations, step,
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(
                object, setNumberSelector, 42));

        [object removeObserver:observer forKeyPath:@"number"];

        [object release];
        [observer release];
    }
}

static void benchmarkKVCMediatedArray(NSInteger iter, NSInteger options) {
    @autoreleasepool {
        TestKVCMediatedArray *observee = [TestKVCMediatedArray new];
        Observer *observer = [Observer new];
        SEL addObjectSelector = @selector(addObject:);
        SEL removeLastObject = @selector(removeLastObject);

        [observee addObserver:observer
                   forKeyPath:@"kvcMediatedArray"
                      options:options
                      context:NULL];

        NSObject *objects[iter];
        for (NSInteger i = 0; i < iter; i++) {
            objects[i] = [NSObject new];
        }

        // This array is not assisted with setter functions and should go
        // through the get/mutate/set codepath.
        NSMutableArray *mediatedVersionOfArray =
            [observee mutableArrayValueForKey:@"kvcMediatedArray"];

        // Adding Objects
        BENCHMARK_PROPERTY_OBSERVATION(
            "KVC Mediated Array Observation (nonatomic) - Adding Objects",
            options, iter, iter, 1,
            ((void (*)(id, SEL, id))objc_msgSend)(
                mediatedVersionOfArray, addObjectSelector, objects[i]););

        // Removing Objects
        BENCHMARK_PROPERTY_OBSERVATION(
            "KVC Mediated Array Observation (nonatomic) - Removing Objects",
            options, iter, iter, 1,
            ((void (*)(id, SEL))objc_msgSend)(mediatedVersionOfArray,
                                              removeLastObject););

        [observee removeObserver:observer forKeyPath:@"kvcMediatedArray"];

        for (NSInteger i = 0; i < iter; i++) {
            [objects[i] release];
        }

        [observee release];
        [observer release];
    }
}

static void benchmarkProxyArray(NSInteger iter, NSInteger options) {
    @autoreleasepool {
        TestProxyArray *observee = [TestProxyArray new];
        Observer *observer = [Observer new];

        SEL addObject = @selector(addObject:);
        SEL removeLastObject = @selector(removeLastObject);

        [observee addObserver:observer
                   forKeyPath:@"proxyArray"
                      options:options
                      context:NULL];

        NSObject *objects[iter];
        for (NSInteger i = 0; i < iter; i++) {
            objects[i] = [NSObject new];
        }

        // Returns an NSKeyValueFastMutableArray instance
        NSMutableArray *proxyArray =
            [observee mutableArrayValueForKey:@"proxyArray"];

        BENCHMARK_PROPERTY_OBSERVATION(
            "Proxy Array Observation (nonatomic) - Adding Objects", options,
            iter, iter, 1,
            ((void (*)(id, SEL, id))objc_msgSend)(proxyArray, addObject,
                                                  objects[i]););

        BENCHMARK_PROPERTY_OBSERVATION(
            "Proxy Array Observation (nonatomic) - Removing Objects", options,
            iter, iter, 1,
            ((void (*)(id, SEL))objc_msgSend)(proxyArray, removeLastObject););

        [observee removeObserver:observer forKeyPath:@"proxyArray"];

        for (NSInteger i = 0; i < iter; i++) {
            [objects[i] release];
        }

        [observee release];
        [observer release];
    }
}

static void benchmarkProxySet(NSInteger iter, NSInteger options) {
    @autoreleasepool {
        TestProxySet *observee = [TestProxySet new];
        Observer *observer = [Observer new];

        SEL addObject = @selector(addObject:);
        SEL removeObject = @selector(removeObject:);

        [observee addObserver:observer
                   forKeyPath:@"proxySet"
                      options:options
                      context:NULL];

        NSObject *objects[iter];
        for (NSInteger i = 0; i < iter; i++) {
            objects[i] = [NSObject new];
        }

        // Returns an NSKeyValueFastMutableSet instance which should
        // go through the fast paths (add<key>Object, etc.)
        NSMutableSet *proxySet = [observee mutableSetValueForKey:@"proxySet"];

        BENCHMARK_PROPERTY_OBSERVATION(
            "Proxy Set Observation (nonatomic) - Adding Objects", options, iter,
            iter, 1,
            ((void (*)(id, SEL, id))objc_msgSend)(proxySet, addObject,
                                                  objects[i]););

        BENCHMARK_PROPERTY_OBSERVATION(
            "Proxy Set Observation (nonatomic) - Removing Objects", options,
            iter, iter, 1,
            ((void (*)(id, SEL, id))objc_msgSend)(proxySet, removeObject,
                                                  objects[i]););

        [observee removeObserver:observer forKeyPath:@"proxySet"];

        for (NSInteger i = 0; i < iter; i++) {
            [objects[i] release];
        }

        [observee release];
        [observer release];
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSInteger newOld =
            NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
        NSInteger new = NSKeyValueObservingOptionNew;
        NSInteger old = NSKeyValueObservingOptionOld;

        benchmarkStringPropertyObservation(150000, 300000, 10000, newOld);
        benchmarkStringPropertyObservation(150000, 300000, 10000, new);
        benchmarkStringPropertyObservation(150000, 300000, 10000, old);
        benchmarkNumberPropertyObservation(150000, 300000, 10000, newOld);
        benchmarkNumberPropertyObservation(150000, 300000, 10000, new);
        benchmarkNumberPropertyObservation(150000, 300000, 10000, old);

        for (int i = 0; i < 10; i++) {
            benchmarkProxyArray(150000, newOld);
            benchmarkProxyArray(150000, new);
            benchmarkProxyArray(150000, old);
            benchmarkKVCMediatedArray(150000, newOld);
            benchmarkKVCMediatedArray(150000, new);
            benchmarkKVCMediatedArray(150000, old);
            benchmarkProxySet(15000, newOld);
            benchmarkProxySet(15000, new);
            benchmarkProxySet(15000, old);
        }
    }

    return 0;
}