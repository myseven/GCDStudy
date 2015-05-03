//
//  ViewController.m
//  GCDTest
//
//  Created by spriteApp on 15/5/2.
//  Copyright (c) 2015年 spriteapp. All rights reserved.
//

#import "ViewController.h"


static ViewController *globalSelf;

@interface ViewController ()

@property (nonatomic, strong) dispatch_queue_t globalQueue;
@property (strong, nonatomic) dispatch_queue_t mainQueue;
@property (strong, nonatomic) dispatch_queue_t customSerialQueue;
@property (strong, nonatomic) dispatch_queue_t customConcurrentQueue;


@end

@implementation ViewController

-(instancetype)init {
    self = [super init];
    if (self) {
        self.globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        self.mainQueue = dispatch_get_main_queue();
        self.customSerialQueue = dispatch_queue_create("m", DISPATCH_QUEUE_SERIAL);
        self.customConcurrentQueue = dispatch_queue_create("m", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

//    [self dispatchAsync];
//    [self dispatchSync];
//    [self dispatchBarrier];
//    [self dispathGroup];
//    [self dispatchGroupThreads];
//    
//    DispatchAfter();
//    DispatchApply();
//    DispatchOnce();
//    DispatchSource_Timer();
//    DispatchSource_Read();
    DispatchSource_Write();

}

// 异步队列
- (void)dispatchAsync {
    
    dispatch_async(self.globalQueue, ^{
        NSLog(@"在线程中执行任务, 不阻塞线程");
    });
}

// 同步队列
- (void)dispatchSync {
    dispatch_sync(self.mainQueue, ^{
        NSLog(@"在主线程串行执行, 阻塞线程");
    });
}

// barrier
- (void)dispatchBarrier {
    dispatch_async(self.globalQueue, ^{
        
        dispatch_barrier_async(self.customConcurrentQueue, ^{
            NSLog(@"线程安全的执行");
            
            dispatch_async(self.mainQueue, ^{
                NSLog(@"回到主线程, 更新UI");
            });
        });
    });
}

// group group会累积并维护组内任务数量, 当所有任务结束后, 触发返回消息
- (void)dispathGroup {
    
    dispatch_async(self.globalQueue, ^{
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);        // 开始入组
        for (int i = 0; i < 10; i++) {
            dispatch_async(self.customSerialQueue, ^{
                NSLog(@"一些耗时操作, 需要全部结束后才能继续");
                dispatch_group_leave(group);    // 出组
            });
        }
        /**************************************************************/
        // group wait 会阻塞当前线程, 直到所有任务完成后才回调
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_async(self.mainQueue, ^{
            NSLog(@"更新UI");
        });
        /**************************************************************/
        // group notify 异步执行, 不阻塞当前线程
        dispatch_group_notify(group, self.mainQueue, ^{
            NSLog(@"更新UI");
        });
        /**************************************************************/
        
    });
}

// group 管理多个线程
- (void)dispatchGroupThreads {
    
    dispatch_group_t group = dispatch_group_create();
    
    // 线程1
    dispatch_async(self.globalQueue, ^{
        NSLog(@"线程1 %@",[NSThread currentThread]);
    });
    
    // 线程2
    dispatch_async(self.globalQueue, ^{
        NSLog(@"线程2 %@",[NSThread currentThread]);
    });
    
    // 线程3
    dispatch_async(self.globalQueue, ^{
        NSLog(@"线程3 %@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, self.mainQueue, ^{
        NSLog(@"等待3个线程结束完后 执行");
    });
}

// dispatch Once 只初始化一次,线程安全
id DispatchOnce() {
    static id someObject = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        someObject = [[NSObject alloc] init];
    });
    return someObject;
}

// dispatch After
void DispatchAfter() {
    
    int64_t delay = 10;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"10秒钟后 执行到这里");
    });
}

// apply 循环事件, 循环内部异步调用
void DispatchApply() {
    dispatch_apply(10, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        // 循环执行 10 次
    });
}

/************************** Dispatch Source ******************************/

#pragma mark - dispath Timer
/**
 * interval 循环间隔事件
 * leeway 允许系统误差的最高时间
 */
dispatch_source_t CreateDispatchTimer(uint64_t interval,
                                      uint64_t leeway,
                                      dispatch_queue_t queue,
                                      dispatch_block_t block) {
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval * NSEC_PER_SEC, leeway * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer,block);
        dispatch_resume(timer);
    }
    return timer;
}

// 调用 dispatch timer
void DispatchSource_Timer() {
    
    static dispatch_source_t myTimer;
    static int count = 0;
    myTimer = CreateDispatchTimer(3ull, 1ull, dispatch_get_main_queue(), ^{
        count++;
        NSLog(@"timer excute %d",count);
    });
    
    NSLog(@"%@",myTimer);
    
    // tiemr 结束回调
    dispatch_source_set_cancel_handler(myTimer, ^{
        NSLog(@"myTimer 结束了");
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 结束timer执行
        dispatch_source_cancel(myTimer);
    });
    
}

#pragma mark - dispatch Read 读数据事件监听
dispatch_source_t ProcessContentsOfFile(const char * filename) {
    
    int fd = open(filename, O_RDONLY);
    if (fd == -1) {
        return NULL;
    }
    fcntl(fd, F_SETFL, O_NONBLOCK); // 设置文件操作特性
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    if (!readSource) {
        close(fd);
        return NULL;
    }

    // 设置read事件处理函数 回调块可能会回调多次处理数据等
    dispatch_source_set_event_handler(readSource, ^{
        size_t estimated = dispatch_source_get_data(readSource) + 1;
        char *buffer = (char *)malloc(estimated);
        
        if (buffer) {
            ssize_t actual = read(fd, buffer, estimated);
            NSLog(@"处理文件数据 大小: %zd",actual);
            NSLog(@"%s",buffer);
            
            free(buffer);
            dispatch_source_cancel(readSource);    // 结束source
        }
    });
    
    dispatch_source_set_cancel_handler(readSource, ^{
        NSLog(@"结束处理");
        close(fd);
    });
    
    // 开始监听
    dispatch_resume(readSource);
    return readSource;
    
}

void DispatchSource_Read() {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ball" ofType:@"js"];
    const char * p = [path UTF8String];
    ProcessContentsOfFile(p);
}

#pragma mark - dispatch Write 写数据事件 监听

dispatch_source_t WriteToFile(const char * filename) {
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC,(S_IRUSR | S_IWUSR | S_ISUID | S_ISGID));
    if (fd == -1) {
        return NULL;
    }
    fcntl(fd, F_SETFL);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, fd, 0, queue);
    
    if (!writeSource) {
        close(fd);
        return NULL;
    }
    
    // 回调块可能会回调多次处理数据等
    dispatch_source_set_event_handler(writeSource, ^{

        void *buffer = "0123456789";
        size_t actual = 100;
        write(fd, buffer, actual);
        
        // 当全部写完后的时候 调用取消
        dispatch_source_cancel(writeSource);
    });
    
    dispatch_source_set_cancel_handler(writeSource, ^{
        close(fd);
    });
    dispatch_resume(writeSource);
    
    return writeSource;
    
}

void DispatchSource_Write() {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    path = [path stringByAppendingPathComponent:@"write.txt"];
    const char * p = [path UTF8String];
    WriteToFile(p);
}



@end






















