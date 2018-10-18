//
//  JSONModel+PB.h
//  CarpoolBusiness
//
//  Created by zhanghe on 2018/10/17.
//

#import "JSONModel.h"
#import "GPBMessage.h"

/**
 Convert GPBMessage to JSONModel
 */
@interface JSONModel(PB)

- (instancetype)initWithGPBMessage:(GPBMessage *)pbMessage;

@end
