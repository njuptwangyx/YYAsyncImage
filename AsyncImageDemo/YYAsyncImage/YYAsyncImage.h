//
//  YYAsyncImage.h
//  AsyncImageDemo
//
//  Created by wangyuxiang on 2019/9/16.
//  Copyright © 2019 wangyuxiang. All rights reserved.
//  异步加载本地图片

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^DiaplayBlock)(UIImage *image);

@interface YYAsyncImage : NSObject

/**
 异步加载图片，block回调image
 
 @param name 图片名称
 @param dispalyBlock 回调
 */
+ (void)imageNamed:(NSString *)name dispalyBlock:(DiaplayBlock)dispalyBlock;

/**
 给UIImageViewi和UIButton设置图片
 button默认调这个方法：[setImage:image forState:UIControlStateNormal]
 如果需要给button设置其他state的图或设置BackgroundImage，则调用下面两个方法

 @param name 图片名称
 @param view view
 */
+ (void)imageNamed:(NSString *)name showInView:(id)view;

/**
 给UIButton设置图片

 @param button button
 @param name 图片名称
 @param state UIControlState
 */
+ (void)button:(UIButton *)button setImageNamed:(NSString *)name forState:(UIControlState)state;

/**
 给UIButton设置背景图片
 
 @param button button
 @param name 图片名称
 @param state UIControlState
 */
+ (void)button:(UIButton *)button setBackgroundImageNamed:(NSString *)name forState:(UIControlState)state;

@end


//给UIButton设置图片的填充模式
typedef NS_ENUM(NSInteger, YYAsyncImageButtonImageMode) {
    YYAsyncImageModeSetImage           = 0,   // setImage
    YYAsyncImageModeSetBackgroundImage = 1    // setBackgroundImage
};

@interface YYAsyncImageDto : NSObject

//使用image的对象
@property(nonatomic, weak) id imgObject;

//给UIButton设置图片的填充模式
@property(nonatomic, assign) YYAsyncImageButtonImageMode buttonImageMode;

//给UIButton设置图片的状态
@property(nonatomic, assign) UIControlState buttonControlState;

//获取image的name
@property(nonatomic, strong) NSArray *imgNameArray;

//image存储dict
@property(nonatomic, strong) NSMutableDictionary *imgDict;

//imgObject的hash值，作为key使用
@property(nonatomic, copy) NSString *hashKey;

//自定义展示block，如果赋值，底层不会自动渲染
@property(nonatomic, copy) DiaplayBlock displayBlock;

@end
