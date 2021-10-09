//
//  main.swift
//  simpleP21ReadSample
//
//  Created by Yoshida on 2021/10/05.
//  Copyright © 2021 Tsutomu Yoshida, Minokamo, Japan. All rights reserved.
//

import Foundation
import SwiftSDAIcore
import SwiftSDAIap242
import SwiftAP242PDMkit

//MARK: identify the input p21 data file
let testDataFolder = ProcessInfo.processInfo.environment["TEST_DATA_FOLDER"]!

//let url = URL(fileURLWithPath: testDataFolder + "NIST_CTC_STEP_PMI/nist_ctc_02_asme1_ap242-e2.stp")
let url = URL(fileURLWithPath: testDataFolder + "CAx STEP FILE LIBRARY/s1-c5-214/s1-c5-214.stp")

//MARK: create input character stream
let stepsource = try String(contentsOf: url) 
let charstream = stepsource.makeIterator()

//MARK: create output repository
let repository = SDAISessionSchema.SdaiRepository(name: "examle", description: "example repository")

//MARK: prepare a acceptable step schema list
let schemaList: P21Decode.SchemaList = [
	"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 3 1 4 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 1 1 4 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF  { 1 0 10303 403 3 1 4}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF { 1 0 10303 403 2 1 2}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"CONFIG_CONTROL_DESIGN": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"CONFIGURATION_CONTROL_3D_DESIGN_ED2_MIM_LF { 1 0 10303 403 1 1 4}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
]

//MARK: decode p21 char stream
let p21monitor = MyActivityMonitor()

// create a decoder
guard let decoder = P21Decode.Decoder(output: repository, schemaList: schemaList, monitor: p21monitor)
else {
	print("decoder initialization error")
	exit(1)
}

// do decode
guard let createdModels = decoder.decode(input: charstream) else {
 print("decoder error: \(String(describing: decoder.error))")
 exit(2)
}

//MARK: create a schema instance containing everything decoded

// obtain a reference to a decoded exchange structure
let exchange = decoder.exchangeStructrure!

// create a schema instance
guard let schema = exchange.shcemaRegistory.values.first else { exit(3) }
let schemaInstance = repository.createSchemaInstance(name: "example", schema: schema.schemaDefinition)

// put all decoded models into schema instance
for model in createdModels {
 schemaInstance.add(model:model)
}
schemaInstance.mode = .readOnly
