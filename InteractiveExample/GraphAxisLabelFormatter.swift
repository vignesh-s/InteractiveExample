//
//  GraphAxisLabelFormatter.swift
//  InteractiveExample
//
//  Created by Vignesh on 01/04/2018.
//

import Charts

public class GraphAxisLabelFormatter: IndexAxisValueFormatter {
    
    let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    override public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value > 0 && value < 8 {
            return labels[Int(value) - 1]
        }
        return String(value)
    }
    
}
