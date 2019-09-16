# YYAsyncImage
异步加载本地图片

##Usage
```
#import "YYAsyncImage.h"
...
...
UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 64, 90, 90)];
[YYAsyncImage imageNamed:@"testImage" showInView:imageView];
[self.view addSubview:imageView];
```