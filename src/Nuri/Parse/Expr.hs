module Nuri.Parse.Expr where

import Data.Text (Text , pack)
import Data.List (foldl1')

import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L
import Control.Monad.Combinators.Expr

import Nuri.Parse
import Nuri.Expr

expr :: Parser Expr
expr = arithmetic

arithmetic :: Parser Expr
arithmetic = makeExprParser (try nestedFuncCalls <|> term) table
 where
  table =
    [ [Prefix $ unaryOp "+" Plus, Prefix $ unaryOp "-" Minus]
    , [InfixL $ binaryOp "*" Asterisk, InfixL $ binaryOp "/" Slash]
    , [InfixL $ binaryOp "+" Plus, InfixL $ binaryOp "-" Minus]
    ]
  binaryOp opStr op = do
    pos <- getSourcePos
    BinaryOp pos op <$ L.symbol sc opStr
  unaryOp opStr op = do
    pos <- getSourcePos
    UnaryOp pos op <$ L.symbol sc opStr

nestedFuncCalls :: Parser Expr
nestedFuncCalls = do
  calls <- some funcCall
  let addArg arg (App pos func args) = App pos func (arg : args)
      addArg _   _                   = undefined
  return $ foldl1' addArg calls

funcCall :: Parser Expr
funcCall = do
  args <- many term
  pos  <- getSourcePos
  func <- funcIdentifier
  return $ App pos (Var pos func) args

funcIdentifier :: Parser Text
funcIdentifier =
  lexeme $ pack <$> (notFollowedBy returnKeyword >> some hangulSyllable)

term :: Parser Expr
term = integer <|> identifierExpr <|> parens

parens :: Parser Expr
parens = between (symbol "(") (symbol ")") expr

identifierExpr :: Parser Expr
identifierExpr =
  lexeme $ Var <$> getSourcePos <*> (char '[' >> identifier <* char ']')

identifier :: Parser Text
identifier =
  pack
    <$> ( (++) <$> some allowedChars <*> many
          (char ' ' <|> allowedChars <|> digitChar)
        )
  where allowedChars = hangulSyllable <|> hangulJamo <|> letterChar

integer :: Parser Expr
integer = lexeme $ do
  pos   <- getSourcePos
  value <- zeroNumber <|> decimal
  return $ Lit pos (LitInteger value)
  where zeroNumber = char '0' >> hexadecimal <|> octal <|> binary <|> return 0

binary :: Parser Integer
binary = char' 'b' >> L.binary

octal :: Parser Integer
octal = L.octal

decimal :: Parser Integer
decimal = L.decimal

hexadecimal :: Parser Integer
hexadecimal = char' 'x' >> L.hexadecimal
