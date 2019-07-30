module Helpers where

import           Data.List                      ( sum )
import           Numeric.Extra                  ( intToDouble )

-- | Consequently applies each function to the result of the previous application,
-- | starting with `f xs`, where `f` is the head of the list of functions and xs is
-- | the initial value of the argument.
mapListOfFunctions :: [[a] -> [a]] -> [a] -> [a]
mapListOfFunctions []       = id
mapListOfFunctions (f : fs) = mapListOfFunctions fs . f

-- | Calculates and returns cartesian product
-- | for all the given list's elements,
-- | with no pairs of same elements.
cartesianProductUnique :: [a] -> [(a, a)]
cartesianProductUnique []       = []
cartesianProductUnique (x : xs) = map ((,) x) xs ++ cartesianProductUnique xs

-- | Calculates average value of the list of Double values.
avgDoubles :: [Double] -> Double
avgDoubles ls = sum ls / intToDouble (length ls)

-- | Takes the absolute value of an Int, converts it to Double.
intToAbsDouble :: Int -> Double
intToAbsDouble = intToDouble . abs

-- | Returns 1 if both args are zero, returns 0 if only one arg is zero,
-- | otherwise divides the lesser int over the greater one.
divLesserOverGreater :: Int -> Int -> Double
divLesserOverGreater a b | a == 0 && b == 0 = 1
                         | a == 0 || b == 0 = 0
                         | a < b = intToAbsDouble a / intToAbsDouble b
                         | otherwise = intToAbsDouble b / intToAbsDouble a
