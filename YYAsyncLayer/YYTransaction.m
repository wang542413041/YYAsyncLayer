//
//  YYTransaction.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/4/18.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTransaction.h"


@interface YYTransaction()
@property (nonatomic, strong) id target;
@property (nonatomic, assign) SEL selector;
@end

static NSMutableSet *transactionSet = nil;

/*
监听runloop回调处理
*/
static void YYRunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    if (transactionSet.count == 0) return;
    NSSet *currentSet = transactionSet;
    transactionSet = [NSMutableSet new];
    [currentSet enumerateObjectsUsingBlock:^(YYTransaction *transaction, BOOL *stop) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [transaction.target performSelector:transaction.selector];
#pragma clang diagnostic pop
    }];
}


/*
监听runloop
*/
static void YYTransactionSetup() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        transactionSet = [NSMutableSet new];
        CFRunLoopRef runloop = CFRunLoopGetMain();
        CFRunLoopObserverRef observer;
        
        observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(), // 对象内存分配器
                                           kCFRunLoopBeforeWaiting | kCFRunLoopExit, // 在睡眠和退出时来执行注册的事件
                                           true,      // repeat，观察者是否循环调用
                                           0xFFFFFF,  // after CATransaction(2000000)
                                           YYRunLoopObserverCallBack, NULL); // 回调事件
        CFRunLoopAddObserver(runloop, observer, kCFRunLoopCommonModes);
        CFRelease(observer);
    });
}


@implementation YYTransaction

+ (YYTransaction *)transactionWithTarget:(id)target selector:(SEL)selector{
    if (!target || !selector) return nil;
    YYTransaction *t = [YYTransaction new];
    t.target = target;
    t.selector = selector;
    return t;
}

- (void)commit {
    if (!_target || !_selector) return;
    YYTransactionSetup();
    [transactionSet addObject:self];
}

- (NSUInteger)hash {
    long v1 = (long)((void *)_selector);
    long v2 = (long)_target;
    return v1 ^ v2;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isMemberOfClass:self.class]) return NO;
    YYTransaction *other = object;
    return other.selector == _selector && other.target == _target;
}

@end
