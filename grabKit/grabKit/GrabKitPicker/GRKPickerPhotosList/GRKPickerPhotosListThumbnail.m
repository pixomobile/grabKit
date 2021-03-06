/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2013 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */


#import "GRKPickerPhotosListThumbnail.h"
#import "GRKPickerViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIImageView+AFNetworking.h>

@implementation GRKPickerPhotosListThumbnail


-(id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    if (self) {
        
       [self buildViews];
        
    }

    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    
        [self buildViews];
        
    }

    return self;
}

-(void) buildViews {
    CALayer * layer = self.layer;
    layer.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
    layer.borderWidth = 1.0;
    layer.borderColor = [UIColor colorWithWhite:0.6 alpha:1.0].CGColor;

    // The imageView's frame is 1px smaller in every directions, in order to show the 1px-wide black border of the background image.
    CGRect thumbnailRect = CGRectMake(1, 1, self.bounds.size.width - 2 , self.bounds.size.height - 2 );
    thumbnailImageView = [[UIImageView alloc] initWithFrame:thumbnailRect];
    thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
    thumbnailImageView.clipsToBounds = YES;
    [self.contentView addSubview:thumbnailImageView];

    NSString * path = [GRK_BUNDLE pathForResource:@"thumbnail_selected" ofType:@"png"];
    UIImage * selectedIcon = [UIImage imageWithContentsOfFile:path];
    selectedImageView = [[UIImageView alloc] initWithImage:selectedIcon];
    CGFloat selectedIconSize = round(self.bounds.size.width / 2.5);
    selectedImageView.frame =  CGRectMake(self.contentView.bounds.size.width - selectedIconSize,
                                          0,
                                          selectedIconSize,
                                          selectedIconSize );
    selectedImageView.hidden = YES;
    [self.contentView addSubview:selectedImageView];
}



-(void) prepareForReuse {
    
    thumbnailImageView.image = nil;
    [thumbnailImageView cancelImageRequestOperation];

    selectedImageView.hidden = YES;

    // Fix for issue #27 https://github.com/pierrotsmnrd/grabKit/issues/27
    self.selected = NO;
    
}


-(void)updateThumbnailImage:(NSURL *)thumbnailURL
{
    thumbnailImageView.image = nil;

    if ( [[thumbnailURL absoluteString] hasPrefix:@"assets-library://"] ){
        ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
        [library assetForURL:thumbnailURL resultBlock:^(ALAsset *asset) {
            // You can also load a "fullResolutionImage", but it's heavy ...
            //CGImageRef imgRef = [asset aspectRatioThumbnail];
            CGImageRef imgRef = [asset thumbnail];
            thumbnailImageView.image = [UIImage imageWithCGImage:imgRef];
        } failureBlock:^(NSError *error) {
        }];
    } else {
        [thumbnailImageView setImageWithURL:thumbnailURL];
    }
}

-(void) setSelected:(BOOL)selected {
    
    [super setSelected:selected];
    
    selectedImageView.hidden = ! selected;
    
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
