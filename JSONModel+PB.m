//
//  JSONModel+PB.m
//
//  Created by zhanghe on 2018/10/17.
//

#import "JSONModel+PB.h"
#import "JSONModelClassProperty.h"
#import <objc/runtime.h>

static const char *kPJClassPropertiesKey;
static NSString *_ConvertToCamelCaseFromSnakeCase(NSString *key) {
    NSMutableString *str = [NSMutableString stringWithString:key];
    while ([str containsString:@"_"]) {
        NSRange range = [str rangeOfString:@"_"];
        if (range.location + 1 < [str length]) {
            char c = [str characterAtIndex:range.location + 1];
            [str replaceCharactersInRange:NSMakeRange(range.location, range.length + 1) withString:[[NSString stringWithFormat:@"%c", c] uppercaseString]];
        }
    }
    return str;
}

@implementation JSONModel(PB)

- (instancetype)initWithGPBMessage:(GPBMessage *)pbMessage {
    self = [self init];
    if (self) {
        [self setup];
        [self setPBMessage:pbMessage];
    }
    return self;
}

- (void)setup {
    if (!objc_getAssociatedObject(self.class, &kPJClassPropertiesKey)) {
        [self inspectProperties];
    }
}

- (void)inspectProperties {
    NSMutableDictionary *propertyIndex = [NSMutableDictionary dictionary];
    
    Class class = [self class];
    NSScanner *scanner = nil;
    NSString *propertyType = nil;
    
    while (class != [JSONModel class]) {
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
        
        for (unsigned int i = 0; i < propertyCount; i++) {
            JSONModelClassProperty *p = [[JSONModelClassProperty alloc] init];
            
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);
            
            const char *attrs = property_getAttributes(property);
            NSString *propertyAttributes = @(attrs);
            NSArray *attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            if ([attributeItems containsObject:@"R"]) {
                continue; // to next property
            }
            
            scanner = [NSScanner scannerWithString:propertyAttributes];
            
            [scanner scanUpToString:@"T" intoString:nil];
            [scanner scanString:@"T" intoString:nil];
            
            // check if the property is an instance of a class
            if ([scanner scanString:@"@\"" intoString:&propertyType]) {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];
                p.type = NSClassFromString(propertyType);
                
                // read through the property protocols
                NSString *protocolName = nil;
                while ([scanner scanString:@"<" intoString:NULL]) {
                    [scanner scanUpToString:@">" intoString:&protocolName];
                    if (![@[@"Optional", @"Index", @"Ignore"] containsObject:protocolName]) {
                        p.protocol = protocolName;
                        break;
                    }
                    [scanner scanString:@">" intoString:NULL];
                }
            }
            else {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&propertyType];
                
                
            }
            
            if (![propertyIndex objectForKey:p.name]) {
                [propertyIndex setValue:p forKey:p.name];
            }
        }
        
        free(properties);
        class = [class superclass];
    }
    
    objc_setAssociatedObject(self.class, &kPJClassPropertiesKey, [propertyIndex copy], OBJC_ASSOCIATION_RETAIN);
}

- (void)setPBMessage:(GPBMessage *)pbMessage {
    NSDictionary *propertyIndex = objc_getAssociatedObject(self.class, &kPJClassPropertiesKey);
    for (NSString *propertyName in [propertyIndex allKeys]) {
        JSONModelClassProperty *p = [propertyIndex valueForKey:propertyName];
        
        // read value from pbmessage
        id value = nil;
        @try {
            NSString *pbPropertyName = _ConvertToCamelCaseFromSnakeCase(propertyName);
            if ([p.type isSubclassOfClass:[NSArray class]]) {
                // for repeated properties
                pbPropertyName = [NSString stringWithFormat:@"%@Array", pbPropertyName];
            }
            value = [pbMessage valueForKey:pbPropertyName];
            // TODO: support key mapper
        } @catch (NSException *exception) {
            continue; // to next property
        }
        if (value == nil) {
            continue; // to next property
        } else {
            
        }
        
        // convert gpbmessage to jsonmodel
        if ([value isKindOfClass:[GPBMessage class]] && [p.type isSubclassOfClass:[JSONModel class]]) {
            JSONModel *jsonModel = [[p.type alloc] initWithGPBMessage:value];
            [self setValue:jsonModel forKey:propertyName];
        }
        // convert repeated objects to array
        else if ([value isKindOfClass:[NSArray class]] && [p.type isSubclassOfClass:[NSArray class]]) {
            Class innerClass = NSClassFromString(p.protocol);
            NSMutableArray *array = [NSMutableArray array];
            for (id obj in value) {
                if ([obj isKindOfClass:[GPBMessage class]]) {
                    JSONModel *jsonModel = [[innerClass alloc] initWithGPBMessage:obj];
                    if (jsonModel) {
                        [array addObject:jsonModel];
                    } else {
                        // TODO: warning
                    }
                } else {
                    [array addObject:obj];
                }
            }
            [self setValue:array forKey:propertyName];
        }
        else {
            if (!p.type || (p.type && [value isKindOfClass:p.type])) {
                [self setValue:value forKey:propertyName];
            }
        }
    }
}

@end
