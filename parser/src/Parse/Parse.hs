{-# OPTIONS_GHC -Wall #-}
module Parse.Parse (parse, parseSource) where

import Text.Parsec (char, eof, letter, many, option, (<|>))
import qualified Text.Parsec.Error as Parsec

import qualified AST.Declaration
import qualified AST.Module
import qualified Parse.Declaration as Decl
import Parse.Helpers
import qualified Parse.Module as Module
import qualified Reporting.Region as R
import qualified Reporting.Error.Syntax as Error
import qualified Reporting.Result as Result


parseSource :: String -> Result.Result () Error.Error AST.Module.Module
parseSource src =
  parse src programParser


-- HEADERS AND DECLARATIONS

programParser :: IParser AST.Module.Module
programParser =
  do  (AST.Module.Header name docs exports imports) <- Module.header
      decls <- declarations
      trailingComments <-
          (++)
              <$> option [] freshLine
              <*> option [] spaces
      eof

      return $ AST.Module.Module name docs exports imports (decls ++ (map AST.Declaration.BodyComment trailingComments))


declarations :: IParser [AST.Declaration.Decl]
declarations =
  (++) <$> ((\x -> [x]) <$> Decl.declaration) -- TODO: can there be comments before this?
      <*> (concat <$> many freshDef)


freshDef :: IParser [AST.Declaration.Decl]
freshDef =
    commitIf (freshLine >> (letter <|> char '_')) $
      do  comments <- freshLine
          decl <- Decl.declaration
          return $ (map AST.Declaration.BodyComment comments) ++ [decl]


-- RUN PARSERS

parse :: String -> IParser a -> Result.Result wrn Error.Error a
parse source parser =
  case iParse parser source of
    Right result ->
        return result

    Left err ->
        let pos = R.fromSourcePos (Parsec.errorPos err)
            msgs = Parsec.errorMessages err
        in
            Result.throw (R.Region pos pos) (Error.Parse msgs)
