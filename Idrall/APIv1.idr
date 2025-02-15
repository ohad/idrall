module Idrall.APIv1

import public Idrall.Expr
import public Idrall.Value
import public Idrall.Error
import Idrall.Eval
import Idrall.Check
import Idrall.Parser
import Idrall.ParserNew
import Idrall.Resolve
import public Idrall.IOEither
import Idrall.Path

import System.Directory
import Data.List
import Data.String

-- Test Stuff

data WhichParser = OldParser | NewParser

useParser : WhichParser
-- useParser = OldParser
useParser = NewParser

parseFunction : WhichParser -> String -> Either String (Expr ImportStatement, Int)
parseFunction OldParser = Idrall.Parser.parseExpr
parseFunction NewParser = Idrall.ParserNew.parseExprNew

parseWith : String -> Either String (Expr ImportStatement, Int)
parseWith = parseFunction useParser

public export
exprFromString : String -> IOEither Error (Expr Void)
exprFromString x = do
  x' <- mapErr (ParseError initFC) (liftEither (parseWith x))
  resolve [] Nothing (fst x')

export
resolveFromString : Maybe FilePath -> String -> IOEither Error (Expr Void)
resolveFromString path x = do
  x' <- mapErr (ParseError initFC) (liftEither (parseWith x))
  resolve [] path (fst x')

public export
roundTripEval : String -> IOEither Error Value
roundTripEval x = do
  x' <- exprFromString x
  liftEither (eval Empty x')

export
roundTripCheckEval : String -> IOEither Error Value
roundTripCheckEval x = do
  x' <- exprFromString x
  _ <- liftEither (infer initCxt x')
  liftEither (eval Empty x')

evalQuote : Expr Void -> Either Error (Expr Void)
evalQuote x = do
  v <- eval Empty x
  e <- quote [] v
  pure e

export
roundTripEvalQuote : String -> IOEither Error (Expr Void)
roundTripEvalQuote x = do
  xE <- exprFromString x
  liftEither (evalQuote xE)

export
roundTripCheckEvalQuote : String -> IOEither Error (Expr Void)
roundTripCheckEvalQuote x = do
  xV <- roundTripCheckEval x
  xE <- liftEither (quote [] xV)
  pure $ xE

export
roundTripEvalQuoteConv : String -> String -> IOEither Error ()
roundTripEvalQuoteConv x y = do
  xE <- exprFromString x
  xNf <- liftEither (evalQuote xE)
  yE <- exprFromString y
  yNf <- liftEither (evalQuote yE)
  _ <- liftEither $ conv Empty !(liftEither $ eval Empty xNf) !(liftEither $ eval Empty yNf)
  pure ()

public export
roundTripSynth : String -> IOEither Error (Expr Void, Value)
roundTripSynth x = do
  x' <- exprFromString x
  liftEither (infer initCxt x')

export
roundTripSynthEvalQuote : String -> IOEither Error (Expr Void)
roundTripSynthEvalQuote x = do
  x' <- exprFromString x
  _ <- liftEither (infer initCxt x')
  liftEither (evalQuote x')

public export
roundTripCheck : String -> String -> IOEither Error ()
roundTripCheck x y = do
  x' <- exprFromString x
  y' <- roundTripEval y
  _ <- liftEither (check initCxt x' y')
  pure ()

public export
roundTripConv : String -> String -> IOEither Error ()
roundTripConv x y = do
  do x' <- roundTripEval x
     y' <- roundTripEval y
     _ <- liftEither $ conv Empty x' y'
     pure ()

public export
valueFromString : String -> IOEither Error Value
valueFromString x = do
  _ <- roundTripSynth x
  roundTripEval x

public export
showIOEither : Show a => Show b => IOEither a b -> IO String
showIOEither (MkIOEither x) =
  do x' <- x
     case x' of
          (Left l) => pure $ "Error: " ++ show l
          (Right r) => pure $ "Success: " ++ show r

public export
doStuff : Show a => Show b => (String -> IOEither a b) -> String -> IO ()
doStuff f x =
  putStrLn !(showIOEither (f x))
