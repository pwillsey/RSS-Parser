//
//  RSSParser.h
//  RSSParser
//
//  Created by Peter Willsey on 11-08-03.
//  Copyright 2011 Peter Willsey. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RSSParserDelegate;

@interface RSSParser : NSObject <NSXMLParserDelegate> {
	id<RSSParserDelegate> delegate;
	
	@private
	NSMutableData *RSSData;
	NSMutableString *currentString;
	NSMutableDictionary *channel;
	NSMutableDictionary *currentItem;
	NSMutableArray *elements;
}

@property (nonatomic, assign) id<RSSParserDelegate> delegate;
@property (nonatomic, retain) NSMutableData *RSSData;
@property (nonatomic, retain) NSMutableString *currentString;
@property (nonatomic, retain) NSMutableDictionary *channel;
@property (nonatomic, retain) NSMutableDictionary *currentItem;
@property (nonatomic, retain) NSMutableArray *elements;

- (void)downloadAndParseFeed:(NSURL *)feedURL;

@end

@protocol RSSParserDelegate <NSObject>
@optional
- (void)parserDidFinishParsing:(RSSParser *)parser;
- (void)parserDidParseChannel:(NSDictionary *)channel;
- (void)parserDidParseItem:(NSDictionary *)feedItem;
- (void)parser:(RSSParser *)parser didEncounterError:(NSError *)error;
@end