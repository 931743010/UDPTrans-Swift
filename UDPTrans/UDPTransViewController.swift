//
//  ViewController.swift
//  UDPTrans
//
//  Created by lifubing on 16/3/10.
//  Copyright © 2016年 lifubing. All rights reserved.
//

import UIKit

class UDPTransViewController: UIViewController,AsyncUdpSocketDelegate {
    
    let animationDurationTime:Double = 4.0      // 一次雷达动画持续的时间
    let disPlayLinkFrameInterval:Int = 200      // 雷达动画的频率
    let timerInterval:Int = 4                   // 设备缓存数据清空时间间隔
    
    var reciveSocket:AsyncUdpSocket!            // 接受数据
    var sendSocket:AsyncUdpSocket!              // 发送广播
    var timer:NSTimer!                          // 检测 设备消失
    
    var layer:CALayer!                          //
    var animationGroup:CAAnimationGroup!        // 用作动画
    var disPlayLink:CADisplayLink!              //
    
    var driverIPList:NSMutableArray = []        // 存储设备信息
    var scanDeveiceIPList:NSMutableArray = []   // 缓存timer时间内扫描到的设备信息

    var deveiceTag = 0                          //           记录连接过的设备数量   不能置零
                                                //           并且 标记 添加的视图
                                                //           视图的消除 是根据Tag值
    
    @IBOutlet weak var wifiNameLabel: UILabel!
    @IBOutlet weak var userOfMe: UIImageView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var userName: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        disPlayLink = CADisplayLink.init(target: self, selector: "delayAnimation")
        disPlayLink.frameInterval = disPlayLinkFrameInterval
        disPlayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillResignActive:", name: UIApplicationWillResignActiveNotification, object: nil)
        //监听是否触发home键挂起程序.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: UIApplicationWillResignActiveNotification, object: nil)
        //监听是否重新进入程序程序.
        
        initSocket()
        initUIView()
    }

    override func viewDidAppear(animated: Bool) {
        drawCircle()
        self.view.bringSubviewToFront(self.backButton)
        timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "checkData", userInfo: nil, repeats: true)
    }
    
    deinit {
        NSLog("deinit")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func applicationWillResignActive() {
        NSLog("进入后台");
        
        disPlayLink.paused = true
        timer.invalidate()
        
        sendSocket.close()
        reciveSocket.close()
    }
    
    func applicationDidBecomeActive() {
        NSLog("进入前台")
        
        disPlayLink.paused = false
        timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "checkData", userInfo: nil, repeats: true)
        
        initSocket()
    }
    
    func initSocket() {
        reciveSocket = AsyncUdpSocket.init(delegate: self)
        
        do {
            try reciveSocket.bindToPort(6789)
        } catch {
            // deal with error
            NSLog("reciveSocket init error")
        }
        reciveSocket.receiveWithTimeout(-1, tag: 0)
        
        sendSocket = AsyncUdpSocket.init(delegate: self)        //发送广播
        do {
            try sendSocket.enableBroadcast(true)
            try sendSocket.bindToPort(0)
            try sendSocket.joinMulticastGroup("255.255.255.255")
        } catch {
            NSLog("sendSocket init error")
        }
        
    }
    
    func onUdpSocket(sock: AsyncUdpSocket!, didReceiveData data: NSData!, withTag tag: Int, fromHost host: String!, port: UInt16) -> Bool {
        NSLog("收到 %ld %@ %d",tag,host,port);
        let dataString = String(data: data, encoding: NSUTF8StringEncoding)
        let userName = dataString?.componentsSeparatedByString("myname:").last
        if let IPAdress = host.componentsSeparatedByString("::ffff:").last {
            
            if IPAdress == IPHelper.deviceIPAdress() {
                // 过滤掉来自自身发送的消息
                //持续监听接受消息
                reciveSocket.receiveWithTimeout(-1, tag: 0)
                return true
            }
            //处理消息
            
            if (dataString?.componentsSeparatedByString("发送").count > 1){
                //包含指定数据
                let  alertController = UIAlertController.init(title: IPAdress, message: "收到消息", preferredStyle: UIAlertControllerStyle.Alert)
                let cancelAction = UIAlertAction.init(title: "取消", style: UIAlertActionStyle.Cancel, handler: nil)
                
                alertController.addAction(cancelAction)
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            
            if self.scanDeveiceIPList.indexOfObject(IPAdress) == NSNotFound {
                self.scanDeveiceIPList.addObject(IPAdress)
                //用作 缓存 timer时间 内扫描到的设备
            }
            
            for each in driverIPList {
                if let deveice = each as? DeveiceDataModel {
                    if deveice.IPAdress == IPAdress {
                        //已经添加有设备
                        //持续监听接受消息
                        reciveSocket.receiveWithTimeout(-1, tag: 0)
                        return true
                    }
                }
            }
            
            // 新设备
            //deveiceTag 用做 记录   不能置零
            //           并且 标记 添加的视图
            //           视图的消除 是根据Tag值
            deveiceTag++
            let deveice:DeveiceDataModel = DeveiceDataModel.init(IP: IPAdress, Name: userName, Tag: deveiceTag)
            driverIPList.addObject(deveice)
            addUserToViewWithUserName(deveice.UserName)
        }
        //持续监听接受消息
        reciveSocket.receiveWithTimeout(-1, tag: 0)
        return true
    }

    //
    //每4秒钟刷新一次设备数据
    //
    func checkData() {
        
        let array = NSMutableArray()
        for each in driverIPList {
            if let deveice =  each as? DeveiceDataModel {
                if self.scanDeveiceIPList.indexOfObject(deveice.IPAdress) == NSNotFound {
                    
                    NSLog("= =消失的IP地址是%s", deveice.IPAdress)
                    array.addObject(deveice)  //存储到数组中，待删除
                    
                    for eachView in self.view.subviews {
                        if (eachView.tag == deveice.imagetag) {
                            //根据tag删除添加的View
                            eachView.removeFromSuperview()
                        }
                    }
                }
            }
        }
        
        //删除消失设备的信息
        for each in array {
            if let devece = each as? DeveiceDataModel {
                self.driverIPList.removeObject(devece)
            }
        }
        self.scanDeveiceIPList.removeAllObjects()
    }
    
    func discoverDevices() {
        //发送消息 查找服务器
        
        let str = String(format: "My IP:%s myname:%@",IPHelper.deviceIPAdress(),UIDevice().name)
        sendSocket.sendData(str.dataUsingEncoding(NSUTF8StringEncoding), toHost: "255.255.255.255", port: 6789, withTimeout: -1, tag: 1)
        sendSocket.receiveWithTimeout(-1, tag: 1)
        NSLog("持续搜索中")
    }
    
    func initUIView () {
        userName.text = UIDevice().name
        cheackWifiName()
        backButton.layer.borderWidth = 0.6
        backButton.layer.borderColor = UIColor.whiteColor().CGColor
    }
    //
    // 画圆
    //
    func drawCircle() {

        let xPoint = CGRectGetWidth(UIScreen.mainScreen().bounds) / 2
        let yPoint = self.userOfMe.center.y
        let width = CGRectGetWidth(UIScreen.mainScreen().bounds)  / 2
        let height = CGRectGetWidth(UIScreen.mainScreen().bounds) / 2
        
        for (var i = 1.0; i < 5; i++) {
            
            let solidLine = CAShapeLayer()
            let solidPath = CGPathCreateMutable()
            solidLine.lineWidth = CGFloat(0.6 + 0.1 * i)
            solidLine.strokeColor = UIColor.grayColor().colorWithAlphaComponent(CGFloat(0.4 + 0.1 * i)).CGColor
            solidLine.fillColor = UIColor.clearColor().CGColor
            
            CGPathAddEllipseInRect(solidPath, nil,CGRectMake(xPoint - width / 2 * CGFloat(i),
                                                             yPoint - width / 2 * CGFloat(i),
                                                             width * CGFloat(i),
                                                             height * CGFloat(i)))
            solidLine.path = solidPath
            self.view.layer.addSublayer(solidLine)
        }
    }
    
    func startAnimation() {
        let layer = CALayer()
        layer.cornerRadius = UIScreen.mainScreen().bounds.size.width * 2
        layer.frame = CGRectMake(0, 0, layer.cornerRadius * 2, layer.cornerRadius * 2)
        layer.position = CGPointMake(self.view.layer.position.x, self.userOfMe.layer.position.y)
        
        layer.backgroundColor = UIColor.whiteColor().CGColor
        self.view.layer.addSublayer(layer)
        
        let defaultCurve = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionDefault)
        
        animationGroup = CAAnimationGroup()
        animationGroup.delegate = self
        animationGroup.duration = animationDurationTime
        animationGroup.removedOnCompletion = true
        animationGroup.timingFunction = defaultCurve
        
        let scaleAnimation = CABasicAnimation.init(keyPath: "transform.scale.xy")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = animationDurationTime
        
        let opencityAnimation = CAKeyframeAnimation.init(keyPath: "opacity")
        opencityAnimation.duration = animationDurationTime
        opencityAnimation.values = [0.8,0.4,0.0]
        opencityAnimation.keyTimes = [0,0.5,1.0]
        opencityAnimation.removedOnCompletion = true
        
        let animations = [scaleAnimation,opencityAnimation]
        animationGroup.animations = animations
        layer.addAnimation(animationGroup, forKey: nil)
        self .performSelector("removeLayer:", withObject: layer, afterDelay: 3)

        UIView.animateWithDuration(animationDurationTime / 10, animations: { () -> Void in
            self.userOfMe.transform = CGAffineTransformMakeScale(1.2, 1.2)
            
            }) { (Bool finish) -> Void in
                UIView.animateWithDuration(self.animationDurationTime / 10, animations: { () -> Void in
                    self.userOfMe.transform = CGAffineTransformMakeScale(1, 1)
                })
        }
    }

    func removeLayer (layer:CALayer){
        layer.removeFromSuperlayer()
        self.view.layer.removeAllAnimations()
    }

    func delayAnimation() {
        startAnimation()
        discoverDevices()
        cheackWifiName()
    }
    
    func addUserToViewWithUserName(username:String){
        let newUser = UIImageView.init(image: UIImage.init(named: "userOfSelf.png"))
        newUser.tag = deveiceTag
        newUser.sizeToFit()
        let xPoint:CGFloat = 160
        let yPoint = CGFloat(160) + CGFloat(rand() % 200)
        newUser.frame = CGRectMake(xPoint, yPoint, 50, 50)
        
        let newUserName = UILabel.init(frame: CGRectMake(xPoint, yPoint + newUser.frame.size.width, 120, 30))
        newUserName.textColor = UIColor.whiteColor()
        newUserName.font = UIFont.systemFontOfSize(14)
        newUserName.tag = deveiceTag
        newUserName.center = CGPointMake(newUser.center.x, yPoint + newUser.frame.size.width+12)
        newUserName.textAlignment = NSTextAlignment.Center
        newUserName.text = username
        NSLog("added new user")
        
        newUser.userInteractionEnabled = true
        let tap = UITapGestureRecognizer.init(target: self, action: "tap:")
        newUser.addGestureRecognizer(tap)
        let nameTap = UITapGestureRecognizer.init(target: self, action: "tap:")
        newUserName.addGestureRecognizer(nameTap)
        self.view.addSubview(newUser)
        self.view.addSubview(newUserName)
        
    }
    
    func cheackWifiName() {
        if let wifiName = NetWorkHelper.getWifiName() {
            self.wifiNameLabel.text = String(format: "当前网络:%@", wifiName)
        }else {
            self.wifiNameLabel.text = "当前网络非WIFI环境,请查看帮助"
        }
        
    }
    
    func tap(recognizer : UITapGestureRecognizer) {

        for each in driverIPList {

            if let deveice =  each as? DeveiceDataModel {
                if deveice.imagetag == recognizer.view?.tag {
                    var imageView = UIImageView()
                    for eachView in self.view.subviews {
                        if (eachView.tag == deveice.imagetag) {
                            if let image = eachView as? UIImageView {
                                imageView = image
                            }

                        }
                    }

                    UIView.animateWithDuration(0.3, animations: { () -> Void in
                        imageView.transform = CGAffineTransformMakeScale(1.2, 1.2)
                        
                    }) { (Bool finish) -> Void in
                        
                        UIView.animateWithDuration(0.3, animations: { () -> Void in
                            imageView.transform = CGAffineTransformMakeScale(1, 1)
                        }) { (Bool finish) -> Void in
                        
                            let alertController = UIAlertController.init(title: deveice.IPAdress, message: deveice.UserName, preferredStyle: UIAlertControllerStyle.Alert)
                            let cancelAction = UIAlertAction.init(title: "取消", style: UIAlertActionStyle.Cancel,handler: nil)
                            
                            let titleString = "发送消息给:\(deveice.IPAdress)"
                            let OkAction = UIAlertAction.init(title: titleString, style: UIAlertActionStyle.Default) { (UIAlertAction) -> Void in
                                let sendToUser = AsyncUdpSocket.init(delegate: self)
                                if sendToUser.sendData(("发送消息".dataUsingEncoding(NSUTF8StringEncoding)), toHost: deveice.IPAdress, port: 6789, withTimeout: -1, tag: 0) {
                                    NSLog("发送成功")
                                }else {
                                    NSLog("发送失败")
                                }
                            }
                            
                            alertController.addAction(cancelAction)
                            alertController.addAction(OkAction)
                            self.presentViewController(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }

    @IBAction func back(sender: UIButton) {
        NSLog(" = =dismiss = = ")
        disPlayLink.paused = true
        disPlayLink.invalidate()
        disPlayLink = nil
        
        animationGroup = nil
        
        timer.invalidate()
        timer = nil
        
        reciveSocket.close()
        reciveSocket = nil
        
        sendSocket.close()
        sendSocket = nil
        
        self.scanDeveiceIPList.removeAllObjects()
        self.driverIPList.removeAllObjects()
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
   
    @IBAction func help(sender: AnyObject) {
        
        let alertController = UIAlertController.init(title: "", message: "项目需要做一些简单配置 \n比如: ARC与非ARC混编 swift与OC混编\n 方法很容易搜索到也可以到我简书文章中查看，有什么问题欢迎联系我\n", preferredStyle: UIAlertControllerStyle.Alert)
        let cancelAction = UIAlertAction.init(title: "取消", style: UIAlertActionStyle.Cancel,handler: nil)
        
        let OkAction = UIAlertAction.init(title: "前往我的简书", style: UIAlertActionStyle.Default) { (UIAlertAction) -> Void in
            let url = NSURL.init(string: "http://www.jianshu.com/users/e78a977ccaeb/")
            UIApplication.sharedApplication().openURL(url!)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(OkAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}