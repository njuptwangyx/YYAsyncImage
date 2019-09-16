//
//  ViewController.m
//  AsyncImageDemo
//
//  Created by wangyuxiang on 2019/9/16.
//  Copyright © 2019 wangyuxiang. All rights reserved.
//

#import "ViewController.h"
#import "YYAsyncImage.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 64, 90, 90)];
    [YYAsyncImage imageNamed:@"testImage" showInView:imageView];
    [self.view addSubview:imageView];
}

@end
