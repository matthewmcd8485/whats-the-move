//
//  UIColorInputError.swift
//  wtm?
//
//  Created by Matthew McDonnell on 1/16/22.
//

import Foundation

public enum UIColorInputError: Error {
  case missingHashMarkAsPrefix
  case unableToScanHexValue
  case mismatchedHexStringLength
  case outputHexStringForWideDisplayColor
}
