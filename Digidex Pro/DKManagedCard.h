//
//  DKManagedCard.h
//  DigidexKit
//
//  Created by Avery Pierce on 8/10/15.
//  Copyright (c) 2015 Avery Pierce. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

@class DKManagedTag;

@interface DKManagedCard : NSManagedObject {
	NSDictionary *_cardDictionary;
	UIImage *_cardImage;
}

@property (nonatomic, retain) NSString * localPath;
@property (nonatomic, retain) id originalURL;
@property (nonatomic, retain) NSSet *tags;

@property (readonly) NSDictionary *cardDictionary;

@property (readonly) NSURL *cardImageURL;
@property (readonly) UIImage *cardImage;

- (instancetype)initWithContactURL:(NSURL *)URL insertIntoManagedObjectContext:(NSManagedObjectContext *)moc;

@end

@interface DKManagedCard (CoreDataGeneratedAccessors)

- (void)addTagsObject:(DKManagedTag *)value;
- (void)removeTagsObject:(DKManagedTag *)value;
- (void)addTags:(NSSet *)values;
- (void)removeTags:(NSSet *)values;

@end
