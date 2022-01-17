//
//  UIColor.swift
//  wtm?
//
//  Created by Matthew McDonnell on 1/16/22.
//

import UIKit

extension UIColor {
  /// The shorthand three-digit hexadecimal representation of color.
  /// #RGB defines to the color #RRGGBB.
  ///
  /// - parameter hex3: Three-digit hexadecimal value.
  /// - parameter alpha: 0.0 - 1.0. The default is 1.0.
  public convenience init(hex3: UInt16, alpha: CGFloat = 1) {
    let divisor = CGFloat(15)
    let red = CGFloat((hex3 & 0xF00) >> 8) / divisor
    let green = CGFloat((hex3 & 0x0F0) >> 4) / divisor
    let blue = CGFloat( hex3 & 0x00F) / divisor
    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  /// The shorthand four-digit hexadecimal representation of color with alpha.
  /// #RGBA defines to the color #RRGGBBAA.
  ///
  /// - parameter hex4: Four-digit hexadecimal value.
  public convenience init(hex4: UInt16) {
    let divisor = CGFloat(15)
    let red = CGFloat((hex4 & 0xF000) >> 12) / divisor
    let green = CGFloat((hex4 & 0x0F00) >> 8) / divisor
    let blue = CGFloat((hex4 & 0x00F0) >> 4) / divisor
    let alpha = CGFloat( hex4 & 0x000F       ) / divisor
    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  /// The six-digit hexadecimal representation of color of the form #RRGGBB.
  ///
  /// - parameter hex6: Six-digit hexadecimal value.
  public convenience init(hex6: UInt32, alpha: CGFloat = 1) {
    let divisor = CGFloat(255)
    let red = CGFloat((hex6 & 0xFF0000) >> 16) / divisor
    let green = CGFloat((hex6 & 0x00FF00) >> 8) / divisor
    let blue = CGFloat( hex6 & 0x0000FF       ) / divisor
    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  /// The six-digit hexadecimal representation of color with alpha of the form #RRGGBBAA.
  ///
  /// - parameter hex8: Eight-digit hexadecimal value.
  public convenience init(hex8: UInt32) {
    let divisor = CGFloat(255)
    let red = CGFloat((hex8 & 0xFF000000) >> 24) / divisor
    let green = CGFloat((hex8 & 0x00FF0000) >> 16) / divisor
    let blue = CGFloat((hex8 & 0x0000FF00) >> 8) / divisor
    let alpha = CGFloat( hex8 & 0x000000FF       ) / divisor
    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  /// The rgba string representation of color with alpha of the form #RRGGBBAA/#RRGGBB, throws error.
  ///
  /// - parameter rgba: String value.
  public convenience init(rgbaThrows rgba: String) throws {
    guard rgba.hasPrefix("#") else {
      throw UIColorInputError.missingHashMarkAsPrefix
    }

    let hexString = String(rgba[String.Index(utf16Offset: 1, in: rgba)...])
    var hexValue: UInt32 = 0

    guard Scanner(string: hexString).scanHexInt32(&hexValue) else {
      throw UIColorInputError.unableToScanHexValue
    }

    switch hexString.count {
    case 3:
      self.init(hex3: UInt16(hexValue))
    case 4:
      self.init(hex4: UInt16(hexValue))
    case 6:
      self.init(hex6: hexValue)
    case 8:
      self.init(hex8: hexValue)
    default:
      throw UIColorInputError.mismatchedHexStringLength
    }
  }

  /// The rgba string representation of color with alpha of the form #RRGGBBAA/#RRGGBB, fails to default color.
  ///
  /// - parameter rgba: String value.
  public convenience init(_ rgba: String, defaultColor: UIColor = UIColor.clear) {
      guard let color = try? UIColor(named: rgba) else {
      self.init(cgColor: defaultColor.cgColor)
      return
    }

    self.init(cgColor: color.cgColor)
  }

  /// Hex string of a UIColor instance, throws error.
  ///
  /// - parameter includeAlpha: Whether the alpha should be included.
  public func hexStringThrows(_ includeAlpha: Bool = true) throws -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    guard red >= 0 && red <= 1 && green >= 0 && green <= 1 && blue >= 0 && blue <= 1 else {
      throw UIColorInputError.outputHexStringForWideDisplayColor
    }

    if includeAlpha {
      return String(format: "#%02X%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
    } else {
      return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
  }

  /// Hex string of a UIColor instance, fails to empty string.
  ///
  /// - parameter includeAlpha: Whether the alpha should be included.
  public func hexString(_ includeAlpha: Bool = true) -> String {
    guard let hexString = try? hexStringThrows(includeAlpha) else {
      return ""
    }

    return hexString
  }
}

extension String {
  /// Convert argb string to rgba string.
  public func argb2rgba() -> String? {
    guard self.hasPrefix("#") else {
      return nil
    }

    let hexString = String(self[self.index(self.startIndex, offsetBy: 1)...])
    switch hexString.count {
    case 4:
      let firstHalf = String(hexString[self.index(self.startIndex, offsetBy: 1)...])
      let secondHalf = String(hexString[..<self.index(self.startIndex, offsetBy: 1)])
      return "#\(firstHalf)\(secondHalf)"
    case 8:
      let firstHalf = String(hexString[self.index(self.startIndex, offsetBy: 2)...])
      let secondHalf = String(hexString[..<self.index(self.startIndex, offsetBy: 2)])
      return "#\(firstHalf)\(secondHalf)"
    default:
      return nil
    }
  }
}
