//
//  OSocketRocketManager.h
//  OSocketRocketManager
//
//  Created by Leuang on 2017/8/22.
//  Copyright © 2017年 OrangeDev. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol OSocketDelegate <NSObject>

@optional

- (void)oSocketReceiveMessage:(id)message;

- (void)oSocketConnectSuccess;

- (void)oSocketConnectFailWithError:(NSError*)error;

- (void)oSocketConnectCloseWithCode:(NSInteger)code reason:(NSString*)reason wasClean:(BOOL)wasClean;

- (void)oSocketConnectReceivePong:(NSData*)pongPayload;

@end

typedef NS_ENUM(NSInteger, OSocketReceiveType){
    OSocketReceiveTypeForMessage,
    OSocketReceiveTypeForPong
};

typedef NS_ENUM(NSInteger, OSocketSendType){
    OSocketSendTypeForMessage,
    OSocketSendTypeForPing
};

typedef NS_ENUM(NSInteger, OSocketStatus){
    OSocketStatusConnected,
    OSocketStatusFailure,
    OSocketStatusClosed,
    OSocketStatusClosedByUser,
    OSocketStatusReconnecting
};

typedef void(^OSocketReceiveBlock)(id message, OSocketReceiveType type);

typedef void(^OSocketSuccessBlock)();

typedef void(^OSocketFailureBlock)(NSError *error);

typedef void(^OSocketCloseBlock)(NSInteger code, NSString *reason, BOOL wasClean);

//typedef void(^OSocketReceivePongBlock)(NSData *message);(合并到OSocketReceiveBlock中)

@interface OSocketRocketManager : NSObject

/**
 重连次数,默认5次（ps：重连方式一开始马上重连，之后以2的reconnectCount次方重连)
 */
@property (nonatomic, assign) NSUInteger reconnectCount;

@property (nonatomic, copy) NSString *socketURL;

/**
 心跳发的ping 默认发空字符串
 */
@property (nonatomic, copy) NSString *pingMsg;

@property (nonatomic, assign) NSUInteger pingInterval;

@property (nonatomic, assign) NSUInteger pingTimeout;

@property (nonatomic, weak) id <OSocketDelegate> delegate;

@property (nonatomic, copy) OSocketReceiveBlock receive;

@property (nonatomic, copy) OSocketSuccessBlock success;

@property (nonatomic, copy) OSocketFailureBlock failure;

@property (nonatomic, copy) OSocketCloseBlock close;

@property (nonatomic, assign, readonly) OSocketStatus socketStatus;

//@property (nonatomic, copy) OSocketReceivePongBlock receivePong;

+ (instancetype)shareManager;

/**
 socket连接（delegate使用）
 */
- (void)connect;

/**
 socket关闭（delegate使用）
 */
- (void)disConnect;

/**
 socket连接（block使用）

 @param success 连接成功
 @param failure 连接失败
 @param receive 信息接收
 */
- (void)oSocketConnectSuccess:(OSocketSuccessBlock)success failure:(OSocketFailureBlock)failure receive:(OSocketReceiveBlock)receive;

/**
 （block delegate 通用）

 @param data 发送信息
 @param type 发送类型
 @return 当前发送信息时socket状态，主要方便hub显示
 */
- (OSocketStatus)oSocketSend:(id)data type:(OSocketSendType)type;

/**
 （block使用）

 @param close socket关闭
 */
- (void)oSocketClose:(OSocketCloseBlock)close;


/**
 用于socket连接后，数据同步（配合自己后台使用的）
 */
- (void)oSocketSync;
@end
