//
//  RSSParser.m
//  RSSParser
//
//  Created by Peter Willsey on 11-08-03.
//  Copyright 2011 Peter Willsey. All rights reserved.
//

#import "RSSParser.h"

#pragma mark Private Methods

@interface RSSParser (Private)
- (void)parseRSSFeed;
@end

@implementation RSSParser (Private)

- (void)parseRSSFeed {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:self.RSSData];
	if (parser) {
		[parser setDelegate:self];
		[parser setShouldProcessNamespaces:NO];
		[parser setShouldReportNamespacePrefixes:NO];
		[parser setShouldResolveExternalEntities:NO];
		
		[parser parse];
		[parser release];
	} else {
		if ([self.delegate respondsToSelector:@selector(errorOccurred:)]) {
			NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
			[errorInfo setObject:@"Unable to create parser" forKey:@"NSLocalizedDescriptionKey"];
			[self.delegate errorOccurred:[NSError errorWithDomain:@"com.peterwillsey.rssparser" code:2 userInfo:errorInfo]];
		}
	}
	
	[RSSData release];
	
	[pool release];
}

@end

#pragma mark -
#pragma mark Public Methods

@implementation RSSParser

@synthesize delegate;
@synthesize RSSData;
@synthesize currentString;
@synthesize channel;
@synthesize currentItem;
@synthesize elements;

- (void)downloadAndParseFeed:(NSURL *)feedURL {
	NSURLRequest *rssRequest = [NSURLRequest requestWithURL:feedURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	
	NSURLConnection *rssConnection = [[NSURLConnection alloc] initWithRequest:rssRequest delegate:self];
	if (rssConnection) {
		self.RSSData = [NSMutableData data];
	} else {
		if ([self.delegate respondsToSelector:@selector(errorOccurred:)]) {
			NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
			[errorInfo setObject:@"Unable to create connection" forKey:@"NSLocalizedDescriptionKey"];
			[self.delegate errorOccurred:[NSError errorWithDomain:@"com.peterwillsey.rssparser" code:1 userInfo:errorInfo]];
		}
	}
}

#pragma mark -
#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[self.RSSData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.RSSData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {	
	[NSThread detachNewThreadSelector:@selector(parseRSSFeed) toTarget:self withObject:nil];
	
	[connection release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[connection release];
	[RSSData release];
		
	if ([self.delegate respondsToSelector:@selector(errorOccurred:)]) {
		[self.delegate errorOccurred:error];
	}
	if ([self.delegate respondsToSelector:@selector(parserDidFinishParsing:)]) {
		[self.delegate parserDidFinishParsing:self];
	}
}

#pragma mark -
#pragma mark NSXMLParser Delegate Methods

- (void)parserDidStartDocument:(NSXMLParser *)parser {
	self.elements = [NSMutableArray array];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {	
	if ([self.delegate respondsToSelector:@selector(errorOccurred:)]) {
		[self.delegate errorOccurred:parseError];
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if ([[elementName lowercaseString] isEqualToString:@"item"]) {
		self.currentItem = [NSMutableDictionary dictionaryWithCapacity:0];
	} else if ([[elementName lowercaseString] isEqualToString:@"channel"]) {
		self.channel = [NSMutableDictionary dictionaryWithCapacity:0];
	}
	
	[self.elements addObject:elementName];
	self.currentString = nil;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	[self.elements removeLastObject];
	NSString *parentElement = [self.elements lastObject];
	
	if ([[elementName lowercaseString] isEqualToString:@"title"] && [[parentElement lowercaseString] isEqualToString:@"channel"]) {
		[self.channel setObject:self.currentString forKey:@"title"];
	} else if ([[elementName lowercaseString] isEqualToString:@"link"] && [[parentElement lowercaseString] isEqualToString:@"channel"]) {
		[self.channel setObject:self.currentString forKey:@"link"];
	} else if ([[elementName lowercaseString] isEqualToString:@"description"] && [[parentElement lowercaseString] isEqualToString:@"channel"]) {
		[self.channel setObject:self.currentString forKey:@"description"];
	} else if ([[elementName lowercaseString] isEqualToString:@"channel"]) {
		if ([self.delegate respondsToSelector:@selector(parserDidParseChannel:)]) {
			[self.delegate parserDidParseChannel:self.channel];
		}
		self.channel = nil;
	} else if ([[elementName lowercaseString] isEqualToString:@"title"] && [[parentElement lowercaseString] isEqualToString:@"item"]) {
		[self.currentItem setObject:self.currentString forKey:@"title"];
	} else if ([[elementName lowercaseString] isEqualToString:@"link"] && [[parentElement lowercaseString] isEqualToString:@"item"]) {
		[self.currentItem setObject:self.currentString forKey:@"link"];
	} else if ([[elementName lowercaseString] isEqualToString:@"description"] && [[parentElement lowercaseString] isEqualToString:@"item"]) {
		[self.currentItem setObject:self.currentString forKey:@"description"];
	} else if ([[elementName lowercaseString] isEqualToString:@"pubDate"] && [[parentElement lowercaseString] isEqualToString:@"item"]) {
		[self.currentItem setObject:self.currentString forKey:@"pubDate"];
	} else if ([[elementName lowercaseString] isEqualToString:@"item"]) {
		if ([self.delegate respondsToSelector:@selector(parserDidParseItem:)]) {
			[self.delegate parserDidParseItem:self.currentItem];
		}
		
		self.currentItem = nil;
	}
	
	self.currentString = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {	
	if (self.currentString == nil) {
		self.currentString = [NSMutableString string];
	}
		
	[self.currentString appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
	if ([self.delegate respondsToSelector:@selector(parserDidFinishParsing:)]) {
		[self.delegate parserDidFinishParsing:self];
	}
	[elements release];
}

#pragma mark -
#pragma mark Clean Up

- (void)dealloc {	
	[super dealloc];
}

@end
