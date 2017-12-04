//
//  ViewController.swift
//  AccelGyroEndpoint
//
//  Created by Jay Tucker on 11/29/17.
//  Copyright © 2017 Imprivata. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var dataLabel: UILabel!
    
    private var bluetoothManager: BluetoothManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        updateButton.isEnabled = false
        dataLabel.isHidden = true
        
        bluetoothManager = BluetoothManager()
        bluetoothManager.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func updateNow(_ sender: Any) {
        bluetoothManager.updateNow()
    }
    
}

extension ViewController: BluetoothManagerDelegate {
    
    func updateConnection(bluetoothConnection: BluetoothConnection) {
        log("updateConnection \(bluetoothConnection)")
        connectionLabel.text = bluetoothConnection.rawValue.capitalized + (bluetoothConnection == .searching ? "..." : "")
        if bluetoothConnection == .connected {
            updateButton.isEnabled = true
            dataLabel.isHidden = false
            dataLabel.text = "..."
        } else {
            updateButton.isEnabled = false
        }
    }

    func updateData(data: String, isRequested: Bool) {
        log("updateData \(data) \(isRequested)")
        dataLabel.text = data
        dataLabel.textColor = isRequested ? .green : .black
    }
    
}

