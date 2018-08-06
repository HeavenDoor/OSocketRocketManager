//
//  OSocketRocketManager.m
//  OSocketRocketManager
//
//  Created by Leuang on 2017/8/22.
//  Copyright © 2017年 OrangeDev. All rights reserved.
//

#import "OSocketRocketManager.h"

#import "SocketRocket.h"

#define BeatDuration  2        //心跳频率
#define MaxBeatMissCount   5   //最大心跳丢失数
#define dispatch_main_async_safe_o(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

@interface OSocketRocketManager ()<SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *webSocket;

@property (nonatomic, assign) NSTimeInterval reConnectTime;

@property (nonatomic, weak) NSTimer *heartBeat;

@property (nonatomic, assign) __block NSInteger beatCount;

@property (nonatomic) OSocketStatus socketStatus;

@end

@implementation OSocketRocketManager

@synthesize socketStatus = _socketStatus;

+ (instancetype)shareManager{
    static OSocketRocketManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.reconnectCount = 5;
        instance.pingMsg = @"";
    });
    return instance;
}

- (void)oSocketConnectSuccess:(OSocketSuccessBlock)success failure:(OSocketFailureBlock)failure receive:(OSocketReceiveBlock)receive{
    
    [OSocketRocketManager shareManager].success = success;
    [OSocketRocketManager shareManager].failure = failure;
    [OSocketRocketManager shareManager].receive = receive;
    
    [self connect];
}

- (OSocketStatus)oSocketSend:(id)data type:(OSocketSendType)type{
    
    //    if (_webSocket.readyState != SR_OPEN) return [OSocketRocketManager shareManager].socketStatus;
    
    if ([OSocketRocketManager shareManager].socketStatus == OSocketStatusConnected){
        switch (type) {
            case OSocketSendTypeForMessage:
                [_webSocket send:data];
                break;
                
            case OSocketSendTypeForPing:
                [_webSocket sendPing:data];
                break;
                
            default:
                break;
        }
    }
    
    return [OSocketRocketManager shareManager].socketStatus;
}

- (void)oSocketClose:(OSocketCloseBlock)close{
    
    [OSocketRocketManager shareManager].close = close;
    [self disConnect];
}

- (void)connect{
    if (_webSocket) {
        [_webSocket close];
        _webSocket = nil;
    };
    
    _webSocket = [[SRWebSocket alloc]initWithURL:[NSURL URLWithString:self.socketURL]];
    _webSocket.delegate = self;
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusClosed;
    [_webSocket open];
    
}

- (void)reconnect{
    
    [self o_disConnect];
    
    if (_reConnectTime > (int)pow(2, _reconnectCount)) return;
    
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusReconnecting;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _webSocket = nil;
        [self connect];
    });
    
    if (_reConnectTime == 0) {
        _reConnectTime = 2;
    }else {
        _reConnectTime *= 2;
    }
}

- (void)disConnect{
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusClosedByUser;
    [self o_disConnect];
}

- (void)o_disConnect{
    
    [self destoryHeartBeat];
    
    _beatCount = 0;
    _reConnectTime = 0;
    
    if (_webSocket) {
        [_webSocket close];
        _webSocket = nil;
    }
}

- (void)sendBeat
{
    
    dispatch_main_async_safe_o(^{
        //        __weak typeof (self) weakSelf=self;
        //        心跳设置为3分钟，NAT超时一般为5分钟
        //        _heartBeat = [NSTimer scheduledTimerWithTimeInterval:BeatDuration repeats:YES block:^(NSTimer * _Nonnull timer) {
        //
        //            [weakSelf beating];
        //        }];
        // 真机运行 出现循坏引用问题 改为旧方法就木有问题````
        _heartBeat = [NSTimer scheduledTimerWithTimeInterval:self.pingInterval target:self selector:@selector(beating)
                                                    userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_heartBeat forMode:NSRunLoopCommonModes];
    })
}

- (void)beating{
    _beatCount++;
    //超过5次未收到服务器心跳 , 置为未连接状态
    if (_beatCount > MaxBeatMissCount) {
        [self destoryHeartBeat];
        //更新连接状态
        [OSocketRocketManager shareManager].socketStatus = OSocketStatusClosed;
        [self reconnect];
    }else{
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        [self oSocketSend:self.pingMsg type:OSocketSendTypeForPing];
    }
}

-(void)destoryHeartBeat
{
    if (_heartBeat) {
        [_heartBeat invalidate];
        _heartBeat = nil;
    }
}

- (void)oSocketSync
{
    
}

- (void)dealloc{
    [self disConnect];
    
}

#pragma mark -- SRWebSocketDelegate
- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusConnected;
    
    if (_delegate && [_delegate respondsToSelector:@selector(oSocketConnectSuccess)]) {
        [_delegate oSocketConnectSuccess];
    }
    
    [OSocketRocketManager shareManager].success ? [OSocketRocketManager shareManager].success() : nil;
    
    _reConnectTime = 0;
    _beatCount = 0;
    
    [self sendBeat];
    
    [self oSocketSync];
    
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusFailure;
    
    if (_delegate && [_delegate respondsToSelector:@selector(oSocketConnectFailWithError:)]) {
        [_delegate oSocketConnectFailWithError:error];
    }
    
    [OSocketRocketManager shareManager].failure ? [OSocketRocketManager shareManager].failure(error) : nil;
    
    //[self reconnect];
    
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusConnected;
    
    if (_delegate && [_delegate respondsToSelector:@selector(oSocketReceiveMessage:)]) {
        [_delegate oSocketReceiveMessage:message];
    }
    
    [OSocketRocketManager shareManager].receive ? [OSocketRocketManager shareManager].receive(message,OSocketReceiveTypeForMessage) : nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    
    if ([OSocketRocketManager shareManager].socketStatus != OSocketStatusClosedByUser) {
        [OSocketRocketManager shareManager].socketStatus = OSocketStatusClosed;
        //[self reconnect];
    }else{
        [self disConnect];
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(oSocketConnectCloseWithCode:reason:wasClean:)]) {
        [_delegate oSocketConnectCloseWithCode:code reason:reason wasClean:wasClean];
    }
    
    [OSocketRocketManager shareManager].close ? [OSocketRocketManager shareManager].close(code,reason,wasClean) : nil;
    
    
    self.webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    
    [OSocketRocketManager shareManager].socketStatus = OSocketStatusConnected;
    
    if (_delegate && [_delegate respondsToSelector:@selector(oSocketConnectReceivePong:)]) {
        [_delegate oSocketConnectReceivePong:pongPayload];
    }
    
    _beatCount = 0;
    
    [OSocketRocketManager shareManager].receive ? [OSocketRocketManager shareManager].receive(pongPayload,OSocketReceiveTypeForPong) : nil;
    
}



@end
