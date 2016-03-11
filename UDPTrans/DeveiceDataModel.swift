//
//  DeveiceDataModel.swift
//  UDPTrans
//
//  Created by lifubing on 16/3/10.
//  Copyright © 2016年 lifubing. All rights reserved.
//

import UIKit

class DeveiceDataModel {
    var IPAdress:String
    var UserName:String
    var imagetag:Int
    
    init(IP:String,Name:String?,Tag:Int) {

        self.IPAdress = IP
        self.imagetag = Tag
        
        if Name != nil {
            self.UserName = Name!
        }else {
            self.UserName = ""
        }

    }
}
