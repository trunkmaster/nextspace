/** Definition of class NSUnit
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Mon Sep 30 15:58:21 EDT 2019

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSUnit_h_GNUSTEP_BASE_INCLUDE
#define _NSUnit_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_12, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

/**
 * Unit converter.  This is an abstract class.
 */
GS_EXPORT_CLASS
@interface NSUnitConverter : NSObject
/**
 * For a given unit, returns the specified value of that unit based on the units dimension.
 */
- (double) baseUnitValueFromValue: (double)value;

/**
 * For a unit, returns the specified value of the base unit in terms of that unit.
 */
- (double) valueFromBaseUnitValue: (double)baseUnitValue;
@end

/**
 * Linear converter... for things like C to F conversion...
 */
GS_EXPORT_CLASS
@interface NSUnitConverterLinear : NSUnitConverter <NSCoding>
{
  double _coefficient;
  double _constant;
}

/**
 * Initialize with the coefficient.
 */
- (instancetype) initWithCoefficient: (double)coefficient;

/**
 * Initialize with the coefficient and constant.
 */
- (instancetype) initWithCoefficient: (double)coefficient
			    constant: (double)constant;

/**
 * Return the coefficient.
 */
- (double) coefficient;

/**
 * Return the constant.
 */
- (double) constant;
@end

/**
 * Units...  abstract...
 */
GS_EXPORT_CLASS
@interface NSUnit : NSObject <NSCopying, NSCoding>
{
  NSString *_symbol;
}
/**
 * Initialize an NSUnit instance.
 */
- (instancetype) init;

/**
 * Initialize NSUnit with a given symbol.
 */
- (instancetype) initWithSymbol: (NSString *)symbol;

/**
 * The symbol used by a given unit.
 */
- (NSString *) symbol;

@end

/**
 * Dimension using units....
 */
GS_EXPORT_CLASS
@interface NSDimension : NSUnit <NSCoding>
{
    double _value;
    NSUnitConverter *_converter;
}

/**
 * The NSUnitConverter instance used for this NSDimension object.
 */
- (NSUnitConverter *) converter;

/**
 * Initialize with symbol and an NSUnitConverter.
 */
- (instancetype) initWithSymbol: (NSString *)symbol converter: (NSUnitConverter *)converter;

/**
 * Return a base unit.
 */
+ (instancetype) baseUnit;

@end

// Predefined....
/**
 * Units of accelleration.  Base unit - metersPerSecondSquared
 */
GS_EXPORT_CLASS
@interface NSUnitAcceleration : NSDimension

/**
 * Units of accelleration in meters per second squared.
 */
+ (NSUnitAcceleration *) metersPerSecondSquared;

/**
 * Units of accelleration equal to the gravitational constant.
 */
+ (NSUnitAcceleration *) gravity;

@end

/**
 * Angle units.  Base unit - degrees
 */
GS_EXPORT_CLASS
@interface NSUnitAngle : NSDimension

/**
 * Units of angle in degrees.
 */
+ (NSUnitAngle *) degrees;

/**
 * Units of angle in arc minutes.
 */
+ (NSUnitAngle *) arcMinutes;

/**
 * Units of angle arc seconds.
 */
+ (NSUnitAngle *) arcSeconds;

/**
 * Units of angle in radians.
 */
+ (NSUnitAngle *) radians;

/**
 * Units of area in square megameters.
 */
+ (NSUnitAngle *) gradians;

/**
 * Units of area in square megameters.
 */
+ (NSUnitAngle *) revolutions;

@end

/**
 * Units of area.  Base unit - squareMeters
 */
GS_EXPORT_CLASS
@interface NSUnitArea : NSDimension

/**
 * Units of area in square megameters.
 */
+ (NSUnitArea *) squareMegameters;

/**
 * Units of area in square kilometers.
 */
+ (NSUnitArea *) squareKilometers;

/**
 * Units of area in square meters.
 */
+ (NSUnitArea *) squareMeters;

/**
 * Units of area in square centimeters.
 */
+ (NSUnitArea *) squareCentimeters;

/**
 * Units of area in square millimeters.
 */
+ (NSUnitArea *) squareMillimeters;

/**
 * Units of area in square micrometers.
 */
+ (NSUnitArea *) squareMicrometers;

/**
 * Units of area in square nanometers.
 */
+ (NSUnitArea *) squareNanometers;

/**
 * Units of area in square inches.
 */
+ (NSUnitArea *) squareInches;

/**
 * Units of area in square feet.
 */
+ (NSUnitArea *) squareFeet;

/**
 * Units of area in square yards.
 */
+ (NSUnitArea *) squareYards;

/**
 * Units of area in square miles.
 */
+ (NSUnitArea *) squareMiles;

/**
 * Units of area in acres/
 */
+ (NSUnitArea *) acres;

/**
 * Units of area in ares.
 */
+ (NSUnitArea *) ares;

/**
 * Units of area in hectares.
 */
+ (NSUnitArea *) hectares;

@end

/**
 * Units of concentration.  Base unit - gramsPerLiter.
 */
GS_EXPORT_CLASS
@interface NSUnitConcentrationMass : NSDimension

/**
 * Concentration units in grams per liter.
 */
+ (NSUnitConcentrationMass *) gramsPerLiter;

/**
 * Concentration units in milligrams per deciliter.
 */
+ (NSUnitConcentrationMass *) milligramsPerDeciliter;

/**
 * Concentration units in grams per mole.
 */
+ (NSUnitConcentrationMass *) millimolesPerLiterWithGramsPerMole: (double)gramsPerMole;

@end

/**
 * Units of dispersion.  Base unit - partsPerMillion
 */
GS_EXPORT_CLASS
@interface NSUnitDispersion : NSDimension

/**
 * Units of dispersion in parts per million.
 */
+ (NSUnitDispersion *) partsPerMillion;

@end

/**
 * Units of duration.  Base unit - seconds
 */
GS_EXPORT_CLASS
@interface NSUnitDuration : NSDimension

/**
 * Units of duration in seconds.
 */
+ (NSUnitDuration *) seconds;

/**
 * Units of duration in minutes.
 */
+ (NSUnitDuration *) minutes;

/**
 * Units of duration in hours.
 */
+ (NSUnitDuration *) hours;

@end

/**
 * Units of electric charge.  Base unit - coulombs
 */
GS_EXPORT_CLASS
@interface NSUnitElectricCharge : NSDimension

/**
 * The units of eletric charge in coulombs.
 */
+ (NSUnitElectricCharge *) coulombs;

/**
 * The units of eletric charge in megaampere hours.
 */
+ (NSUnitElectricCharge *) megaampereHours;

/**
 * The units of eletric charge in kiloampere hours.
 */
+ (NSUnitElectricCharge *) kiloampereHours;

/**
 * The units of eletric charge in ampere hours.
 */
+ (NSUnitElectricCharge *) ampereHours;

/**
 * The units of eletric charge in milliampere hours.
 */
+ (NSUnitElectricCharge *) milliampereHours;

/**
 * The units of eletric charge in microampere hours.
 */
+ (NSUnitElectricCharge *) microampereHours;

@end

/**
 * Units of electric current.  Base unit - amperes
 */
GS_EXPORT_CLASS
@interface NSUnitElectricCurrent : NSDimension

/**
 * The units of eletric current in megaamperes.
 */
+ (NSUnitElectricCurrent *) megaamperes;

/**
 * The units of eletric current in kiloamperes.
 */
+ (NSUnitElectricCurrent *) kiloamperes;

/**
 * The units of eletric current in amperes.
 */
+ (NSUnitElectricCurrent *) amperes;

/**
 * The units of eletric current in milliamperes.
 */
+ (NSUnitElectricCurrent *) milliamperes;

/**
 * The units of eletric current in microamperes.
 */
+ (NSUnitElectricCurrent *) microamperes;

@end

/**
 * Units of electric potential.  Base unit - volts
 */
GS_EXPORT_CLASS
@interface NSUnitElectricPotentialDifference : NSDimension

/**
 * The units of eletric potential in megavolts.
 */
+ (NSUnitElectricPotentialDifference *) megavolts;

/**
 * The units of eletric potential in kilovolts.
 */
+ (NSUnitElectricPotentialDifference *) kilovolts;

/**
 * The units of eletric potential in volts.
 */
+ (NSUnitElectricPotentialDifference *) volts;

/**
 * The units of eletric potential in millivolts.
 */
+ (NSUnitElectricPotentialDifference *) millivolts;

/**
 * The units of eletric potential in microvolts.
 */
+ (NSUnitElectricPotentialDifference *) microvolts;

@end

/**
 * Units of electric resistance. Base unit - ohms
 */
GS_EXPORT_CLASS
@interface NSUnitElectricResistance : NSDimension

/**
 * The units of eletric resistance in megaohms.
 */
+ (NSUnitElectricResistance *) megaohms;

/**
 * The units of eletric resistance in kiloohms.
 */
+ (NSUnitElectricResistance *) kiloohms;

/**
 * The units of eletric resistance in ohms.
 */
+ (NSUnitElectricResistance *) ohms;

/**
 * The units of eletric resistance in milliohms.
 */
+ (NSUnitElectricResistance *) milliohms;

/**
 * The units of eletric resistance in microohms.
 */
+ (NSUnitElectricResistance *) microohms;

@end

/**
 * Units of Energy.  Base unit - joules
 */
GS_EXPORT_CLASS
@interface NSUnitEnergy : NSDimension

/**
 * The units of energy in kilojoules.
 */
+ (NSUnitEnergy *) kilojoules;

/**
 * The units of energy in joules.
 */
+ (NSUnitEnergy *) joules;

/**
 * The units of energy in kilocalories.
 */
+ (NSUnitEnergy *) kilocalories;

/**
 * The units of energy in calories.
 */
+ (NSUnitEnergy *) calories;

/**
 * The units of energy in kilawatt hours.
 */
+ (NSUnitEnergy *) kilowattHours;

@end

/**
 * Units of frequency.  Base unit - hertz
 */
GS_EXPORT_CLASS
@interface NSUnitFrequency : NSDimension

/**
 * The units of frequency in terahertz.
 */
+ (NSUnitFrequency *) terahertz;

/**
 * The units of frequency in gigahertz.
 */
+ (NSUnitFrequency *) gigahertz;

/**
 * The units of frequency in megahertz.
 */
+ (NSUnitFrequency *) megahertz;

/**
 * The units of frequency in kilohertz.
 */
+ (NSUnitFrequency *) kilohertz;

/**
 * The units of frequency in hertz.
 */
+ (NSUnitFrequency *) hertz;

/**
 * The units of frequency in millihertz.
 */
+ (NSUnitFrequency *) millihertz;

/**
 * The units of frequency in microhertz.
 */
+ (NSUnitFrequency *) microhertz;

/**
 * The units of frequency in nanohertz.
 */
+ (NSUnitFrequency *) nanohertz;

@end

/**
 * Units of fuel efficiency.  Base unit - litersPer100Kilometers
 */
GS_EXPORT_CLASS
@interface NSUnitFuelEfficiency : NSDimension

/**
 * The units of fuel efficiency in liters per 100 kilometers.
 */
+ (NSUnitFuelEfficiency *) litersPer100Kilometers;

/**
 * The units of fuel efficiency in miles per imperial gallon.
 */
+ (NSUnitFuelEfficiency *) milesPerImperialGallon;

/**
 * The units of fuel efficiency in miles per gallon.
 */
+ (NSUnitFuelEfficiency *) milesPerGallon;

@end

/**
 * Units of length. Base unit - meters
 */
GS_EXPORT_CLASS
@interface NSUnitLength : NSDimension

/**
 * The units of length in megameters.
 */
+ (NSUnitLength *) megameters;

/**
 * The units of length in kilometers.
 */
+ (NSUnitLength *) kilometers;

/**
 * The units of length in hectometers.
 */
+ (NSUnitLength *) hectometers;

/**
 * The units of length in decameters.
 */
+ (NSUnitLength *) decameters;

/**
 * The units of length in meters.
 */
+ (NSUnitLength *) meters;

/**
 * The units of length in decimeters.
 */
+ (NSUnitLength *) decimeters;

/**
 * The units of length in centimeters.
 */
+ (NSUnitLength *) centimeters;

/**
 * The units of length in millimeters.
 */
+ (NSUnitLength *) millimeters;

/**
 * The units of length in micrometers.
 */
+ (NSUnitLength *) micrometers;

/**
 * The units of length in nanometers.
 */
+ (NSUnitLength *) nanometers;

/**
 * The units of length in picometers.
 */
+ (NSUnitLength *) picometers;

/**
 * The units of length in inches.
 */
+ (NSUnitLength *) inches;

/**
 * The units of length in feet.
 */
+ (NSUnitLength *) feet;

/**
 * The units of length in yards.
 */
+ (NSUnitLength *) yards;

/**
 * The units of length in miles.
 */
+ (NSUnitLength *) miles;

/**
 * The units of length in scandanavian miles.
 */
+ (NSUnitLength *) scandinavianMiles;

/**
 * The units of length in light years.
 */
+ (NSUnitLength *) lightyears;

/**
 * The units of length in nautical miles.
 */
+ (NSUnitLength *) nauticalMiles;

/**
 * The units of length in fathoms.
 */
+ (NSUnitLength *) fathoms;

/**
 * The units of length in furlongs.
 */
+ (NSUnitLength *) furlongs;

/**
 * The units of length in astronomical units.
 */
+ (NSUnitLength *) astronomicalUnits;

/**
 * The units of length in parsecs.
 */
+ (NSUnitLength *) parsecs;

@end

/**
 * Units of illumination.  Base unit - lux
 */
GS_EXPORT_CLASS
@interface NSUnitIlluminance : NSDimension

/**
 * The units of illuminance in lux.
 */
+ (NSUnitIlluminance *) lux;

@end

/**
 * Units of mass. Base unit - kilograms
 */
GS_EXPORT_CLASS
@interface NSUnitMass : NSDimension

/**
 * The mass units in kilograms.
 */
+ (NSUnitMass *) kilograms;

/**
 * The mass units in grams.
 */
+ (NSUnitMass *) grams;

/**
 * The mass units in decigrams.
 */
+ (NSUnitMass *) decigrams;

/**
 * The mass units in centigrams.
 */
+ (NSUnitMass *) centigrams;

/**
 * The mass units in milligrams.
 */
+ (NSUnitMass *) milligrams;

/**
 * The mass units in micrograms.
 */
+ (NSUnitMass *) micrograms;

/**
 * The mass units in nanograms.
 */
+ (NSUnitMass *) nanograms;

/**
 * The mass units in picograms.
 */
+ (NSUnitMass *) picograms;

/**
 * The mass units in ounces.
 */
+ (NSUnitMass *) ounces;

/**
 * The mass units in pounds.
 */
+ (NSUnitMass *) pounds;

/**
 * The mass units in stones.
 */
+ (NSUnitMass *) stones;

/**
 * The mass units in metric tons.
 */
+ (NSUnitMass *) metricTons;

/**
 * The mass units in short tons.
 */
+ (NSUnitMass *) shortTons;

/**
 * The mass units in carats.
 */
+ (NSUnitMass *) carats;

/**
 * The mass units in ounces troy.
 */
+ (NSUnitMass *) ouncesTroy;

/**
 * The mass units in slugs.
 */
+ (NSUnitMass *) slugs;

@end

/**
 * Used to represent power.  Base unit - watts
 */
GS_EXPORT_CLASS
@interface NSUnitPower : NSDimension

/**
 * The power units in terawatts.
 */
+ (NSUnitPower *) terawatts;

/**
 * The power units in gigawatts.
 */
+ (NSUnitPower *) gigawatts;

/**
 * The power units in megawatts.
 */
+ (NSUnitPower *) megawatts;

/**
 * The power units in kilowatts.
 */
+ (NSUnitPower *) kilowatts;

/**
 * The power units in watts.
 */
+ (NSUnitPower *) watts;

/**
 * The power units in milliwatts.
 */
+ (NSUnitPower *) milliwatts;

/**
 * The power units in microwatts.
 */
+ (NSUnitPower *) microwatts;

/**
 * The power units in nanowatts.
 */
+ (NSUnitPower *) nanowatts;

/**
 * The power units in picowatts.
 */
+ (NSUnitPower *) picowatts;

/**
 * The power units in femtowatts.
 */
+ (NSUnitPower *) femtowatts;

/**
 * The power units in horsepower.
 */
+ (NSUnitPower *) horsepower;

@end

/**
 * Used to represent pressure. Base unit - newtonsPerMetersSquared (equivalent to 1 pascal)
 */
GS_EXPORT_CLASS
@interface NSUnitPressure : NSDimension

/**
 * The newtons per meters squared unit of pressure.
 */
+ (NSUnitPressure *) newtonsPerMetersSquared;

/**
 * The gigapascals unit of pressure.
 */
+ (NSUnitPressure *) gigapascals;

/**
 * The megapascals unit of pressure.
 */
+ (NSUnitPressure *) megapascals;

/**
 * The kilopascals unit of pressure.
 */
+ (NSUnitPressure *) kilopascals;

/**
 * The hetcopascals unit of pressure.
 */
+ (NSUnitPressure *) hectopascals;

/**
 * The inches of mercury unit of pressure.
 */
+ (NSUnitPressure *) inchesOfMercury;

/**
 * The bars unit of pressure.
 */
+ (NSUnitPressure *) bars;

/**
 * The millibars unit of pressure.
 */
+ (NSUnitPressure *) millibars;

/**
 * The millimeters of mercury of pressure.
 */
+ (NSUnitPressure *) millimetersOfMercury;

/**
 * The pounds of per square inch of pressure.
 */
+ (NSUnitPressure *) poundsForcePerSquareInch;

@end

/**
 * Used to represent speed. Base unit is meters per second.
 */
GS_EXPORT_CLASS
@interface NSUnitSpeed : NSDimension

/**
 * The meters per second measurement of speed.
 */
+ (NSUnitSpeed *) metersPerSecond;

/**
 * The kilometers per hour measurement of speed.
 */
+ (NSUnitSpeed *) kilometersPerHour;

/**
 * The miles per hour measurement of speed.
 */
+ (NSUnitSpeed *) milesPerHour;

/**
 * The knots measurement of speed.
 */
+ (NSUnitSpeed *) knots;

@end

/**
 * Used to represent temperature quantities.
 * The base unit of this class is kelvin.
 */
GS_EXPORT_CLASS
@interface NSUnitTemperature : NSDimension

/**
 * The kelvin unit of temperature.
 */
+ (NSUnitTemperature *) kelvin;

/**
 * The kelvin unit of celsius.
 */
+ (NSUnitTemperature *) celsius;

/**
 * The kelvin unit of fahenheit.
 */
+ (NSUnitTemperature *) fahrenheit;

@end

/**
 * Typically this is used to represent specific quantities.
 * The base unit of this class is liters.
 */
GS_EXPORT_CLASS
@interface NSUnitVolume : NSDimension

/**
 * The megaliters unit of volume.
 */
+ (NSUnitVolume *) megaliters;

/**
 * The kiloliters unit of volume.
 */
+ (NSUnitVolume *) kiloliters;

/**
 * The liters unit of volume.
 */
+ (NSUnitVolume *) liters;

/**
 * The deciliters unit of volume.
 */
+ (NSUnitVolume *) deciliters;

/**
 * The centiliters unit of volume.
 */
+ (NSUnitVolume *) centiliters;

/**
 * The milliliters unit of volume.
 */
+ (NSUnitVolume *) milliliters;

/**
 * The cubic kilometers unit of volume.
 */
+ (NSUnitVolume *) cubicKilometers;

/**
 * The cubic meters unit of volume.
 */
+ (NSUnitVolume *) cubicMeters;

/**
 * The cubic decimeters unit of volume.
 */
+ (NSUnitVolume *) cubicDecimeters;

/**
 * The cubic centimeteres unit of volume.
 */
+ (NSUnitVolume *) cubicCentimeters;

/**
 * The cubic millimeters unit of volume.
 */
+ (NSUnitVolume *) cubicMillimeters;

/**
 * The cubic inches unit of volume.
 */
+ (NSUnitVolume *) cubicInches;

/**
 * The cubic feet unit of volume.
 */
+ (NSUnitVolume *) cubicFeet;

/**
 * The cubic yards unit of volume.
 */
+ (NSUnitVolume *) cubicYards;

/**
 * The cubic miles unit of volume.
 */
+ (NSUnitVolume *) cubicMiles;

/**
 * The acre feet unit of volume.
 */
+ (NSUnitVolume *) acreFeet;

/**
 * The bushels unit of volume.
 */
+ (NSUnitVolume *) bushels;

/**
 * The teaspoons unit of volume.
 */
+ (NSUnitVolume *) teaspoons;

/**
 * The tablespoons unit of volume.
 */
+ (NSUnitVolume *) tablespoons;

/**
 * The fluid ounces unit of volume.
 */
+ (NSUnitVolume *) fluidOunces;

/**
 * The cups unit of volume.
 */
+ (NSUnitVolume *) cups;

/**
 * The pints unit of volume.
 */
+ (NSUnitVolume *) pints;

/**
 * The quarts unit of volume.
 */
+ (NSUnitVolume *) quarts;

/**
 * The gallons unit of volume.
 */
+ (NSUnitVolume *) gallons;

/**
 * The imperial teaspoons unit of volume.
 */
+ (NSUnitVolume *) imperialTeaspoons;

/**
 * The imperial tablespoons unit of volume.
 */
+ (NSUnitVolume *) imperialTablespoons;

/**
 * The imperial fluid ounces unit of volume.
 */
+ (NSUnitVolume *) imperialFluidOunces;

/**
 * The imperial pints unit of volume.
 */
+ (NSUnitVolume *) imperialPints;

/**
 * The imperial quarts unit of volume.
 */
+ (NSUnitVolume *) imperialQuarts;

/**
 * The imperial gallons unit of volume.
 */
+ (NSUnitVolume *) imperialGallons;

/**
 * The metric cups unit of volume.
 */
+ (NSUnitVolume *) metricCups;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSUnit_h_GNUSTEP_BASE_INCLUDE */
