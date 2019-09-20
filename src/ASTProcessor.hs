{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-|
Module      : ASTProcessor
Description : Parses AST related data from .json files

Parses AST that is output by semantic library
(https://github.com/github/semantic/) in .json format.
-}
module ASTProcessor
    ( parseRawJSONFile
    , FunctionData
    , StatementsCountMap
    , filePath
    , lineNumber
    , name
    , arity
    , stmtsCountMap
    , stmtsCount
    )
where

import           Prelude                 hiding ( lookup )
import           Data.HashMap.Strict            ( HashMap
                                                , fromListWith
                                                , lookup
                                                , mapWithKey
                                                )
import           Data.Maybe                     ( isJust )
import           Data.Either                    ( rights )
import           Data.Text                      ( Text )
import           Data.Text.Lazy                 ( pack )
import           Data.Text.Lazy.Encoding        ( encodeUtf8 )
import           Data.Aeson
import           Data.Aeson.Types               ( Parser
                                                , parseEither
                                                )
import           Data.Aeson.Lens
import           Control.Lens                   ( cosmos
                                                , filtered
                                                , (^?)
                                                , toListOf
                                                )
import           FileProcessor                  ( RawJSONFile(RawJSONFile) )
import           StatementWeights               ( defaultWeight
                                                , stmtWeights
                                                )

type StatementData = Text

type JSONParsingError = String
type LineNumber = Int
type Language = String
type FunctionIdentifier = String
type Arity = Int
type StatementsCountMap = HashMap Text Double
data FunctionData = FunctionData { filePath :: FilePath
                                 , lineNumber :: LineNumber
                                 , language :: Language
                                 , name :: FunctionIdentifier
                                 , arity :: Arity
                                 , stmtsCountMap :: StatementsCountMap
                                 , stmtsCount :: Int
                                 } deriving Show

data TreeData = TreeData { rootNode :: Value
                         , treeFilePath :: FilePath
                         , treeLanguage :: Language
                         } deriving Show

isKeyPresent :: Text -> Value -> Bool
isKeyPresent keyName v = isJust $ v ^? (key keyName . nonNull)

isStatement :: Value -> Bool
isStatement = isKeyPresent "term"

isTree :: Value -> Bool
isTree = isKeyPresent "tree"

isFunction :: Value -> Bool
isFunction v = v ^? (key "term" . _String) == Just "Function"

getAllElements :: (Value -> Bool) -> Value -> [Object]
getAllElements filterFn = toListOf (cosmos . filtered filterFn . _Object)

getAllStatements :: Value -> [Object]
getAllStatements = getAllElements isStatement

getAllFunctions :: Value -> [Object]
getAllFunctions = getAllElements isFunction

getAllTrees :: Value -> [Object]
getAllTrees = getAllElements isTree

isntStmtsWrapper :: StatementData -> Bool
isntStmtsWrapper sd = sd /= "Statements" && sd /= "StatementBlock"

parseStmtObject :: Object -> Parser StatementData
parseStmtObject o = o .: "term"

-- | Parses all statements, filtering out
-- | statement wrapper nodes.
parseAllStatements :: [Value] -> [StatementData]
parseAllStatements =
    filter isntStmtsWrapper . rights . map (parseEither parseStmtObject) . concatMap getAllStatements

buildStatementsHashMap :: [StatementData] -> StatementsCountMap
buildStatementsHashMap = fromListWith (+) . map (, 1)

multiplyHashMapByWeights :: StatementsCountMap -> StatementsCountMap
multiplyHashMapByWeights = mapWithKey (\k v -> maybe (v * defaultWeight) (v *) $ lookup k stmtWeights)

parseFunctionObject :: FilePath -> Language -> Object -> Parser FunctionData
parseFunctionObject path language o = do
    sourceSpan                   <- o .: "sourceSpan"
    [lineNumber, _]              <- sourceSpan .: "start"
    functionName                 <- o .: "functionName"
    name                         <- functionName .: "name"
    (parameters :: [Value])      <- o .: "functionParameters"
    body                         <- o .: "functionBody"
    (outerStatements :: [Value]) <- body .: "statements"

    let allStatements = parseAllStatements outerStatements
    let weightedStatements = multiplyHashMapByWeights $ buildStatementsHashMap allStatements

    return $ FunctionData path
                          lineNumber
                          language
                          name
                          (length parameters)
                          weightedStatements
                          (length allStatements)

parseTreeFunctions :: TreeData -> [Either String FunctionData]
parseTreeFunctions (TreeData rootNode treeFilePath treeLanguage) = map
    (parseEither $ parseFunctionObject treeFilePath treeLanguage)
    (getAllFunctions rootNode)

parseTreeObject :: Object -> Parser TreeData
parseTreeObject o = do
    (rootNode :: Value) <- o .: "tree"
    treeFilePath        <- o .: "path"
    treeLanguage        <- o .: "language"

    return $ TreeData rootNode treeFilePath treeLanguage

-- | Given `RawJSONFile`, tries to parse its `contents`.
-- | Returns either an error's description, or `ParsedFiles`.
parseRawJSONFile :: RawJSONFile -> Either String [FunctionData]
parseRawJSONFile (RawJSONFile _ contents) =
    let decodedJSON = eitherDecode $ encodeUtf8 $ pack contents
    in  case decodedJSON of
            (Left error) -> Left error
            (Right rootNode) ->
                Right
                    $ rights
                    $ concatMap parseTreeFunctions
                    $ rights
                    $ map (parseEither parseTreeObject)
                    $ getAllTrees rootNode
