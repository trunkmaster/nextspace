#import <Foundation/NSArray.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>

typedef NSData * (^RequestHandlerBlock)(NSURLRequest *);

@interface Route : NSObject

+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                     handler:(RequestHandlerBlock)block;

- (NSString *)method;
- (NSURL *)url;
- (RequestHandlerBlock)block;

- (BOOL)acceptsURL:(NSURL *)url method:(NSString *)method;

@end

@interface HTTPServer : NSObject
- initWithPort:(NSInteger)port routes:(NSArray<Route *> *)routes;

- (NSInteger)port;
- (void)resume;
- (void)suspend;

- (void)setRoutes:(NSArray<Route *> *)routes;
@end
