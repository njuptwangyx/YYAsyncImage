
#import "YYAsyncImage.h"

#define YYAsyncImageHash(object) [NSString stringWithFormat:@"%lu", (unsigned long)[object hash]]

@interface YYAsyncImage()

@property(nonatomic, assign) BOOL asyncEnabled;

@property(nonatomic, assign) BOOL isActive;

@property(nonatomic, strong) NSMutableDictionary *allImgDict;

@property(nonatomic, strong) NSMutableArray *imageNamedArray;

@property(nonatomic, strong) NSMutableArray *imageNamedLoadArray;

@property(nonatomic, strong) NSMutableArray *displayArray;

@property(nonatomic, strong) dispatch_queue_t imageNamedLoadQueue;

@end

@implementation YYAsyncImage

+ (YYAsyncImage *)sharedInstance {
    static YYAsyncImage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YYAsyncImage alloc] init];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        
        if ([[[UIDevice currentDevice] systemVersion] compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending) {
            // 由于[UIImage imageNamed:name]方法在iOS9及之后的系统是线程安全的，所以9之后的系统才异步加载图片，8还是主线程加载。
            _asyncEnabled = YES;
        }
        
        _allImgDict = [NSMutableDictionary dictionary];
        _imageNamedArray = [NSMutableArray array];
        _imageNamedLoadArray = [NSMutableArray array];
        _displayArray = [NSMutableArray array];
        _imageNamedLoadQueue = dispatch_queue_create([[NSString stringWithFormat:@"YYAsyncImage.imageNamedLoad.%@", self] UTF8String], NULL);
        
        YYAsyncImageRunloopObserverSetup();
    }
    return self;
}

+ (void)imageNamed:(NSString *)name dispalyBlock:(DiaplayBlock)dispalyBlock {
    
    if (name.length <= 0) {
        return;
    }
    
    YYAsyncImage *instance = [YYAsyncImage sharedInstance];
    if (instance.asyncEnabled) {
        // 异步加载
        YYAsyncImageDto *dto = [[YYAsyncImageDto alloc] init];
        dto.displayBlock = dispalyBlock;
        dto.imgNameArray = @[name];
        [instance imageNamed_addDTO:dto];
    } else {
        // 主线程加载
        if (dispalyBlock) {
            UIImage *image = [instance getImageNamed:name];
            dispalyBlock(image);
        }
    }
}

+ (void)imageNamed:(NSString *)name showInView:(id)view {
    [[YYAsyncImage sharedInstance] biuldDtoWithName:name view:view controlState:UIControlStateNormal buttonImageMode:YYAsyncImageModeSetImage];
}

+ (void)button:(UIButton *)button setImageNamed:(NSString *)name forState:(UIControlState)state {
    [[YYAsyncImage sharedInstance] biuldDtoWithName:name view:button controlState:state buttonImageMode:YYAsyncImageModeSetImage];
}

+ (void)button:(UIButton *)button setBackgroundImageNamed:(NSString *)name forState:(UIControlState)state {
    [[YYAsyncImage sharedInstance] biuldDtoWithName:name view:button controlState:state buttonImageMode:YYAsyncImageModeSetBackgroundImage];
}

- (void)biuldDtoWithName:(NSString *)name view:(id)view controlState:(UIControlState)state buttonImageMode:(NSInteger)buttonImageMode {
    
    if (name.length <= 0 || !view) {
        return;
    }
    
    if (_asyncEnabled) {
        // 异步加载
        YYAsyncImageDto *dto = [[YYAsyncImageDto alloc] init];
        dto.imgObject = view;
        dto.buttonControlState = state;
        dto.buttonImageMode = buttonImageMode;
        dto.imgNameArray = @[name];
        [self imageNamed_addDTO:dto];
    } else {
        // 主线程加载
        UIImage *image = [self getImageNamed:name];
        if ([view isKindOfClass:[UIImageView class]]){
            [(UIImageView *)view setImage:image];
        } else if ([view isKindOfClass:[UIButton class]]) {
            if (buttonImageMode == 0) {
                [(UIButton *)view setImage:image forState:state];
            } else if (buttonImageMode == 1) {
                [(UIButton *)view setBackgroundImage:image forState:state];
            }
        }
    }
}

- (UIImage *)getImageNamed:(NSString *)name {
    UIImage *image = nil;
    if ([UIScreen mainScreen].bounds.size.width <= 320) {
        // 低性能手机用这种方式加载图片，节约内存，防止卡死或闪退
        image = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:name ofType:@"png"]];
        if (!image) {
            image = [UIImage imageNamed:name];
        }
    } else {
        image = [UIImage imageNamed:name];
    }
    return image;
}

- (void)imageNamed_addDTO:(YYAsyncImageDto *)dto {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self imageNamed_addDTO:dto];
        });
        return;
    }
    
    if (dto.imgNameArray.count <= 0) {
        return;
    }
    
    dto.hashKey = [NSString stringWithFormat:@"%@_%@_%@_%d_%d", YYAsyncImageHash(dto.imgObject), YYAsyncImageHash(dto.displayBlock), dto.imgNameArray[0], (int)dto.buttonImageMode, (int)dto.buttonControlState];
    YYAsyncImageDto *oldDTO = [_allImgDict valueForKey:dto.hashKey];
    if (oldDTO) {
        // 已经有相同的操作了，直接return
        return;
    }
    [_allImgDict setValue:dto forKey:dto.hashKey];
    
    // 待加载array
    [_imageNamedArray addObject:dto];
    [self imageNamed_startLoad];
}

- (void)imageNamed_startLoad {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self imageNamed_startLoad];
        });
        return;
    }
    
    // 是否可以加载
    if (!_isActive) {
        return;
    }
    
    // 当前没有需要加载的图片,返回
    if (_imageNamedArray.count <= 0) {
        return;
    }
    
    // 有图片正在加载，返回
    if (_imageNamedLoadArray.count > 0) {
        return;
    }
    
    // 加载图片
    YYAsyncImageDto *dto = [_imageNamedArray objectAtIndex:0];
    // 从待加载array中移除
    [_imageNamedArray removeObject:dto];
    
    // 加入加载array
    [_imageNamedLoadArray addObject:dto];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_imageNamedLoadQueue, ^{
        if (dto.imgObject || dto.displayBlock) {
            for (NSString *name in dto.imgNameArray) {
                UIImage *image = [self getImageNamed:name];
                [dto.imgDict setValue:image forKey:name];
            }
        }
        [weakSelf imageNamed_finishLoad:dto];
    });
}

- (void)imageNamed_finishLoad:(YYAsyncImageDto *)dto {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self imageNamed_finishLoad:dto];
        });
        return;
    }
    
    // 从加载array中移除
    [_imageNamedLoadArray removeAllObjects];
    
    // 加入展示array
    [self display_addDTO:dto];
    
    // 加载下一个
    [self imageNamed_startLoad];
}

#pragma mark display
- (void)display_addDTO:(YYAsyncImageDto *)dto {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self display_addDTO:dto];
        });
        return;
    }
    
    [_displayArray addObject:dto];
}

- (void)startDisplay {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startDisplay];
        });
        return;
    }
    
    // 如果没有待展示的，返回
    if (_displayArray.count == 0) {
        return;
    }
    
    for (YYAsyncImageDto *dto in _displayArray) {
        UIImage *image = [dto.imgDict.allValues objectAtIndex:0];
        if (dto.displayBlock) {
            dto.displayBlock(image);
        } else if (dto.imgObject) {
            if ([dto.imgObject isKindOfClass:[UIImageView class]]){
                [(UIImageView *)dto.imgObject setImage:image];
            } else if ([dto.imgObject isKindOfClass:[UIButton class]]) {
                if (dto.buttonImageMode == 1) {
                    [(UIButton *)dto.imgObject setBackgroundImage:image forState:dto.buttonControlState];
                } else {
                    [(UIButton *)dto.imgObject setImage:image forState:dto.buttonControlState];
                }
            }
        }
        
        // 加载完成，从allImgDict中移除
        [_allImgDict removeObjectForKey:dto.hashKey];
    }
    
    // 从展示array中移除
    [_displayArray removeAllObjects];
}

static void YYAsyncImageRunloopObserverSetup() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFRunLoopRef runloop = CFRunLoopGetMain();
        CFRunLoopObserverRef observer;
        
        observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(),
                                           kCFRunLoopBeforeWaiting | kCFRunLoopExit,
                                           true,      // repeat
                                           0xFFFFFF,  // after CATransaction(2000000)
                                           YYAsyncImageRunLoopObserverCallBack,
                                           NULL);
        CFRunLoopAddObserver(runloop, observer, kCFRunLoopCommonModes);
        CFRelease(observer);
    });
}

static void YYAsyncImageRunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    static BOOL firstCallBack = YES;
    if (firstCallBack) {
        firstCallBack = NO;
        [YYAsyncImage sharedInstance].isActive = YES;
        [[YYAsyncImage sharedInstance] imageNamed_startLoad];
    }
    
    [[YYAsyncImage sharedInstance] startDisplay];
}

@end


#pragma mark - dto
@implementation YYAsyncImageDto

- (NSMutableDictionary *)imgDict {
    if (!_imgDict) {
        _imgDict = [NSMutableDictionary dictionaryWithCapacity:self.imgNameArray.count];
    }
    return _imgDict;
}

@end
