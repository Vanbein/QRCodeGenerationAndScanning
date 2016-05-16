//
//  ViewController.m
//  QRCodeGenerationAndScanning
//
//  Created by 王斌 on 16/5/16.
//  Copyright © 2016年 Changhong electric Co., Ltd. All rights reserved.
//

#import "GenerateViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface GenerateViewController ()<AVCaptureMetadataOutputObjectsDelegate>

//显示二维码
@property (weak, nonatomic) IBOutlet UIImageView *imgView;

//获取输入的二维码内容
@property (weak, nonatomic) IBOutlet UITextField *textField;

//捕获会话
@property (nonatomic,strong) AVCaptureSession *session;

//预览图层，可以通过输出设备展示被捕获的数据流。
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;

//显示扫描后二维码内容
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation GenerateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - 点击按钮生成二维码

- (IBAction)generateQRCode:(UIButton *)sender {
    [self.textField resignFirstResponder];
    //1.实例化二维码滤镜
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    //2.恢复滤镜的默认属性（因为滤镜有可能保存上一次的属性）
    [filter setDefaults];
    //3.经字符串转化成NSData
    NSData *data = [self.textField.text dataUsingEncoding:NSUTF8StringEncoding];
    //4.通过KVC设置滤镜，传入data，将来滤镜就知道要通过传入的数据生成二维码
    [filter setValue:data forKey:@"inputMessage"];
    //5.生成二维码
    CIImage *image = [filter outputImage];
    //CIImage是CoreImage框架中最基本代表图像的对象，他不仅包含元图像数据，还包含作用在原图像上的滤镜链。
//    UIImage *image1 = [UIImage imageWithCIImage:image];
    //注：像这样将CIImage直接转换成UIImage生成的二维码会比较模糊，但是简单，也可以扫描出信息。
    
    //6.设置生成好的二维码到imageVIew上
//    self.imgView.image = image1;

    //    生成高清二维码的方法
    self.imgView.image = [self createNonInterpolatedUIImageFormCIImage:image withSize:100.0];
}

#pragma mark - 生成高清二维码

- (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    //设置比例
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // 创建bitmap（位图）;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // 保存bitmap到图片
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}

#pragma mark - 点击按钮扫描二维码
- (IBAction)scanQRCode:(UIButton *)sender {
    //1.实例化拍摄设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]; //媒体类型
    
    //2.设置输入设备
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        //防止模拟器崩溃
        NSLog(@"没有摄像头设备");
        return;
    }
    
    //3.设置元数据输出
    //实例化拍摄元数据输出
    AVCaptureMetadataOutput *output=[[AVCaptureMetadataOutput alloc]init];
    //设置输出数据代理
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //4.添加拍摄会话
    //实例化拍摄会话
    AVCaptureSession *session =[[AVCaptureSession alloc]init];
    [session setSessionPreset:AVCaptureSessionPresetHigh];//预设输出质量
    //添加会话输入
    [session addInput:input];
    //添加会话输出
    [session addOutput:output];
    //添加会话输出条码类型
    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    self.session = session;
    
    //5.视频预览图层
    //实例化预览图层
    AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    preview.frame = self.view.bounds;
    //将图层插入当前视图
    [self.view.layer insertSublayer:preview atIndex:100];
    self.previewLayer = preview;
    
    //6.启动会话
    [_session startRunning];
}

//获得的数据在此方法中
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    // 会频繁的扫描，调用代理方法
    // 1. 如果扫描完成，停止会话
    [self.session stopRunning];
    // 2. 删除预览图层
    [self.previewLayer removeFromSuperlayer];
    // 3. 设置界面显示扫描结果
    //判断是否有数据
    if (metadataObjects.count > 0) {
        AVMetadataMachineReadableCodeObject *obj = metadataObjects[0];
        //如果需要对url或者名片等信息进行扫描，可以在此进行扩展
        self.label.text = obj.stringValue;
    }
    //结束扫描
    [self dismissViewControllerAnimated:YES completion:^{
        //不进这儿？
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:self.label.text preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:action];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

@end
