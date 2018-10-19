//
//  JSONModel+PB.h
//
//  Created by zhanghe on 2018/10/17.
//

#import "JSONModel.h"
#import "GPBMessage.h"

@protocol PJKeyMappingProtocol;

/**
 Convert GPBMessage to JSONModel
 */
@interface JSONModel (PB) <PJKeyMappingProtocol>

- (instancetype)initWithGPBMessage:(GPBMessage *)pbMessage;

@end

@protocol PJKeyMappingProtocol <NSObject>

@optional
- (NSDictionary<NSString *, NSString *> *)pbKeyMapper; // <JSONModelKey -> GPBMessageKey>

@end
