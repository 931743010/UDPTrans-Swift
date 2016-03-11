//
//  ViewController.swift
//  UDPTrans
//
//  Created by lifubing on 16/3/10.
//  Copyright © 2016年 lifubing. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func aboutMe(sender: AnyObject) {
        let url = NSURL.init(string: "http://weibo.com/lfbWb")
        UIApplication.sharedApplication().openURL(url!)
//        NSURL* url = [[ NSURL alloc ] initWithString :@"http://weibo.com/lfbWb"];
//        [[UIApplication sharedApplication ] openURL: url];
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
