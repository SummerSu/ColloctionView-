//
//  CircleScrollView.m
//  ColloctionView循环滚动控件
//
//  Created by caokun on 16/1/28.
//  Copyright © 2016年 caokun. All rights reserved.
//

#import "CircleScrollView.h"
#import "CircleViewCell.h"
#import "XLCardSwitchFlowLayout.h"
//居中卡片宽度与据屏幕宽度比例
static float CardWidthScale = 0.7f;
static float CardHeightScale = 0.8f;


@interface CircleScrollView () <UICollectionViewDelegate, UICollectionViewDataSource>
{
    
//    CGFloat _dragStartX;
//    
//    CGFloat _dragEndX;
    
}

@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSArray *images;              // 图片数组
@property (assign, nonatomic) NSInteger imageCount;         // 图片数量
@property (strong, nonatomic) NSMutableArray *cellData;     // 模型数组
// 模型数组开 100 组, 每组 n 张图片id, NSInteger 8 字节, 总大小 800n 个字节
// collectionView 停留在第 50 组模型那, 每次动画停止, 手动设置回第 50 组

@property (strong, nonatomic) UIPageControl *pageControl;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSLock *mLock;



/**
 当前选中位置
 */
//@property (nonatomic, assign, readwrite) NSInteger selectedIndex;

@end

@implementation CircleScrollView

static NSString *CollectionCellID = @"CollectionCellID";

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // 初始化 collectionView
        XLCardSwitchFlowLayout *flowLayout = [[XLCardSwitchFlowLayout alloc] init];
        flowLayout.itemSize = frame.size;
        flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        flowLayout.minimumLineSpacing = 0;
        flowLayout.minimumInteritemSpacing = 0;
        flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
        
//        [flowLayout setItemSize:CGSizeMake([self cellWidth],self.bounds.size.height * CardHeightScale)];
//        [flowLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
//        [flowLayout setMinimumLineSpacing:[self cellMargin]];
//        
        
        self.collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:flowLayout];
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
        self.collectionView.pagingEnabled = YES;
        self.collectionView.showsHorizontalScrollIndicator = NO;
        self.collectionView.showsVerticalScrollIndicator = NO;
        self.collectionView.alwaysBounceHorizontal = YES;
        self.collectionView.alwaysBounceVertical = NO;
        self.collectionView.backgroundColor = [UIColor whiteColor];
        [self.collectionView registerClass:[CircleViewCell class] forCellWithReuseIdentifier:CollectionCellID];       // 注册 cell 重用
        [self addSubview:self.collectionView];
        
        self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 30, self.bounds.size.width, 30)];
        self.pageControl.tag = 100;
//        self.pageControl.backgroundColor = [UIColor redColor];
        self.pageControl.userInteractionEnabled = NO;
        [self addSubview:self.pageControl];
        [self bringSubviewToFront:self.pageControl];
        self.backgroundColor = [UIColor whiteColor];
        self.mLock = [[NSLock alloc] init];
    }
    return self;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.cellData.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CircleViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionCellID forIndexPath:indexPath];
    NSInteger index = [_cellData[indexPath.row] integerValue];
    cell.image = _images[index];
    cell.index = index;

    return cell;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    // 动画停止, 重新定位到第 50 组模型
    int inc = ((int)(scrollView.contentOffset.x / scrollView.frame.size.width)) % _imageCount;
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:50 * _imageCount + inc inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    
    // 设置 PageControl
    self.pageControl.currentPage = inc;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    CircleViewCell *cell = (CircleViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if ([self.delegate respondsToSelector:@selector(didClickImageAtIndex:scrollView:)]) {
        [self.delegate didClickImageAtIndex:cell.index scrollView:self];
    }
}

- (void)setDuringTime:(NSTimeInterval)duringTime {
    _duringTime = duringTime;
    if (duringTime < 0.001) {
        return ;
    }
    [self closeTimer];
    [self openTimer];
}

- (void)images:(NSArray *)images {
    [self.mLock lock];
    [self closeTimer];
    
    _images = images;
    _imageCount = images.count;
    
    // 生成数据源
    self.cellData = [[NSMutableArray alloc] init];
    for (int i=0; i<100; i++) {
        for (int j=0; j<_imageCount; j++) {
            [self.cellData addObject:@(j)];
        }
    }
    [self.collectionView reloadData];
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:50 * _imageCount inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    
    // 设置 PageControl
    self.pageControl.hidden = _imageCount > 1 ? NO : YES;
    self.pageControl.numberOfPages = _imageCount;
    self.pageControl.currentPage = 0;
    
    [self openTimer];
    [self.mLock unlock];
}

- (void)closeTimer {
    if (self.timer) {
        [self.timer invalidate];
    }
}

- (void)openTimer {
    if (_duringTime > 0.8) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:_duringTime target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
    }
}

- (void)onTimer {
    if (self.cellData.count > 0) {
        NSArray *array = [self.collectionView indexPathsForVisibleItems];
        if (array.count == 0) return ;
        
        NSIndexPath *indexPath = array[0];
        NSInteger row = indexPath.row;
        
        if (row % _imageCount == 0) {
            row = 50 * _imageCount;         // 重新定位
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
        }
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:row + 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:YES];
        self.pageControl.currentPage = (row + 1) % _imageCount;
    }
}

//卡片宽度
- (CGFloat)cellWidth {
    return self.bounds.size.width * CardWidthScale;
}

//卡片间隔
- (float)cellMargin {
    return (self.bounds.size.width - [self cellWidth])/4;
}

//设置左右缩进
- (CGFloat)collectionInset {
    return self.bounds.size.width/2.0f - [self cellWidth]/2.0f;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, [self collectionInset], 0, [self collectionInset]);
}

//配置cell居中
- (void)fixCellToCenter {
    //最小滚动距离
    float dragMiniDistance = self.bounds.size.width/20.0f;
//    if (_dragStartX -  _dragEndX >= dragMiniDistance) {
//        _selectedIndex -= 1;//向右
//    }else if(_dragEndX -  _dragStartX >= dragMiniDistance){
//        _selectedIndex += 1;//向左
//    }
    NSInteger maxIndex = [_collectionView numberOfItemsInSection:0] - 1;
//    _selectedIndex = _selectedIndex <= 0 ? 0 : _selectedIndex;
//    _selectedIndex = _selectedIndex >= maxIndex ? maxIndex : _selectedIndex;
    [self scrollToCenter];
}



- (void)scrollToCenter {
    
//    [_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
    
//    [self performDelegateMethod];
}

//- (void)performDelegateMethod {
//    if ([_delegate respondsToSelector:@selector(didClickImageAtIndex:scrollView:)]) {
//        [_delegate didClickImageAtIndex:_selectedIndex scrollView:self];
//    }
//}

@end

