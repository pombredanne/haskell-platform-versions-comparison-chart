{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}
module Main where
import           Prelude hiding (div)
import           Data.Foldable (forM_)
import           Data.List (sortBy)
import           Data.Char (toLower)
import           Data.Function (on)

import qualified Data.Map as Map

import           Text.Blaze.Html5 hiding (head, map, style)
import qualified Text.Blaze.Html5 as Html
import           Text.Blaze.Renderer.String (renderHtml)
import           Text.Blaze.Html5.Attributes hiding (title, name, id)
import qualified Text.Blaze.Html5.Attributes as A

type PackageName = String

type PackageVersion = String

data Visibility = Exposed | Hidden
  deriving (Eq, Show)

data Package = Package {
  packageName       :: PackageName
, packageVersion    :: PackageVersion
, packageVisibility :: Visibility
} deriving (Eq, Show)

type PlatformVersion = String

data Platform = Platform {
  platformVersion     :: PlatformVersion
, platformGhcPackages :: [Package]
, platformPackages    :: [Package]
} deriving (Eq, Show)

-- intermediate data structures, used for processing
data PackageOrigin = PlatformPackage | GhcBootPackage
  deriving (Eq, Show)

main :: IO ()
main = putStrLn . renderHtml . (docTypeHtml ! lang "en") $ do
  Html.head $ do
    meta ! charset "utf-8"
    link ! rel "stylesheet" ! type_ "text/css" ! href "css/bootstrap.css"
    link ! rel "stylesheet" ! type_ "text/css" ! href "css/custom.css"

    title "Haskell Platform Versions Comparison Chart"

  body . (div ! class_ "container") $ do
    div !class_ "page-header" $ h1 $ do
      small "Haskell Platform "
      "Versions Comparison Chart"
    blockquote . p $ do
      em "Ever wanted to know what version of a package is in what Haskell Platform?"
      br
      em "Here you are!"
    table ! class_ "table table-bordered" $ do
      thead . tr $ do
        th ""
        mapM_ (th . toHtml) versions
      tbody $ do
        forM_ packages $ \(name, xs) -> tr $ do
          th (toHtml name)
          showVersions xs
    div ! class_ "legend" $ do
      Html.span ! class_ "alert-success" $ "new version"
      ", "
      "*comes with ghc"

    a ! href "https://github.com/sol/haskell-platform-versions-comparison-chart" $ do
      img ! style "position: absolute; top: 0; right: 0; border: 0;"

          -- red
          -- ! src "https://a248.e.akamai.net/assets.github.com/img/e6bef7a091f5f3138b8cd40bc3e114258dd68ddf/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67"

          -- green
          -- ! src "https://a248.e.akamai.net/assets.github.com/img/abad93f42020b733148435e2cd92ce15c542d320/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f677265656e5f3030373230302e706e67"

          -- black
          -- ! src "https://a248.e.akamai.net/assets.github.com/img/7afbc8b248c68eb468279e8c17986ad46549fb71/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f6461726b626c75655f3132313632312e706e67"

          -- orange
          ! src "https://a248.e.akamai.net/assets.github.com/img/30f550e0d38ceb6ef5b81500c64d970b7fb0f028/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f6f72616e67655f6666373630302e706e67"

          -- gray
          -- ! src "https://a248.e.akamai.net/assets.github.com/img/71eeaab9d563c2b3c590319b398dd35683265e85/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f677261795f3664366436642e706e67"

          ! alt "Fork me on GitHub"

    -- script ! type_ "text/javascript" ! src "js/jquery.js" $ ""
    -- script ! type_ "text/javascript" ! src "js/bootstrap.js" $ ""
    -- script ! type_ "text/javascript" ! src "js/custom.js" $ ""


  where
    showVersions :: [(PlatformVersion, (PackageOrigin, Package))] -> Html
    showVersions xs = go versions
      where
        go (v1:v2:vs) = do
          case (lookup v1 xs, lookup v2 xs) of
            (Nothing, _)       -> td ""
            (Just p1, Just p2) -> showPackageVersion ((packageVersion . snd) p1 /= (packageVersion . snd) p2) p1
            (Just p1, Nothing) -> showPackageVersion False p1
          go (v2:vs)
        go (v:[])    = maybe (td "") (showPackageVersion False) (lookup v xs)
        go []        = return ()


    showPackageVersion :: Bool -> (PackageOrigin, Package) -> Html
    showPackageVersion changed (origin, Package _ version visibility) =
      (td . new . ghc . toHtml) s
      where
        s = case visibility of
          Exposed -> version
          Hidden  -> "(" ++ version ++ ")"

        ghc = case origin of
          GhcBootPackage  -> (Html.span ! class_ "ghc-boot" {- ! A.title "comes with ghc" -}) . (>> "*")
          PlatformPackage -> id

        new
          | changed   = Html.span ! class_ "alert-success"
          | otherwise = id

    packages :: [(PackageName, [(PlatformVersion, (PackageOrigin, Package))])]
    packages = sortBy (compare `on` (map toLower . fst)) $ Map.toList $ foldr f Map.empty releases
      where
        f (Platform version xs ys) m = foldr g m (map (\x -> (GhcBootPackage, x)) xs ++ map (\x -> (PlatformPackage, x)) ys)
          where
            g x@(_, Package name _ _) = Map.insertWith' (++) name [(version, x)]

    versions :: [PlatformVersion]
    versions = [v | Platform v _ _ <- releases]

-- | Construct an exposed package.
package :: PackageName -> PackageVersion -> Package
package name version = Package name version Exposed

-- | A list of Haskell Platform releases.
--
-- How to add a new release?
--
-- (1) ghc-pkg list
-- (2) s/\(.*\)-\([^-]*\)$/  , package "\1" "\2"
-- (3) manually adjust `packageExposed` for hidden packages
-- (4) add to `releases`
--
releases :: [Platform]
releases =
  Platform "2011.4.0.0" ghc_7_0_4  hp_2011_4_0_0 :
  Platform "2011.2.0.1" ghc_7_0_3  hp_2011_2_0_1 :
  Platform "2011.2.0.0" ghc_7_0_2  hp_2011_2_0_0 :
  Platform "2010.2.0.0" ghc_6_12_3 hp_2010_2_0_0 :
  []

ghc_7_0_4 :: [Package]
ghc_7_0_4 = [
    package "Cabal" "1.10.2.0"
  , package "array" "0.3.0.2"
  , package "base" "4.3.1.0"
  , package "bin-package-db" "0.0.0.0"
  , package "bytestring" "0.9.1.10"
  , package "containers" "0.4.0.0"
  , package "directory" "1.1.0.0"
  , package "extensible-exceptions" "0.1.1.2"
  , package "ffi" "1.0"
  , package "filepath" "1.2.0.0"
  , Package "ghc" "7.0.4" Hidden
  , Package "ghc-binary" "0.5.0.2" Hidden
  , package "ghc-prim" "0.2.0.0"
  , Package "haskell2010" "1.0.0.0" Hidden
  , package "haskell98" "1.1.0.1"
  , package "hpc" "0.5.0.6"
  , package "integer-gmp" "0.2.0.3"
  , package "old-locale" "1.0.0.2"
  , package "old-time" "1.0.0.6"
  , package "pretty" "1.0.1.2"
  , package "process" "1.0.1.5"
  , package "random" "1.0.0.3"
  , package "rts" "1.0"
  , package "template-haskell" "2.5.0.0"
  , package "time" "1.2.0.3"
  , package "unix" "2.4.2.0"
  ]

hp_2011_4_0_0 :: [Package]
hp_2011_4_0_0 = [
    package "GLUT" "2.1.2.1"
  , package "HTTP" "4000.1.2"
  , package "HUnit" "1.2.4.2"
  , package "OpenGL" "2.2.3.0"
  , package "QuickCheck" "2.4.1.1"
  , package "cgi" "3001.1.7.4"
  , package "deepseq" "1.1.0.2"
  , package "fgl" "5.4.2.4"
  , package "haskell-platform" "2011.4.0.0"
  , package "haskell-src" "1.0.1.4"
  , package "html" "1.0.1.2"
  , package "mtl" "2.0.1.0"
  , package "network" "2.3.0.5"
  , package "parallel" "3.1.0.1"
  , package "parsec" "3.1.1"
  , package "regex-base" "0.93.2"
  , package "regex-compat" "0.95.1"
  , package "regex-posix" "0.95.1"
  , package "stm" "2.2.0.1"
  , package "syb" "0.3.3"
  , package "text" "0.11.1.5"
  , package "transformers" "0.2.2.0"
  , package "xhtml" "3000.2.0.4"
  , package "zlib" "0.5.3.1"
  ]

ghc_7_0_3 :: [Package]
ghc_7_0_3 = [
    package "Cabal" "1.10.1.0"
  , package "array" "0.3.0.2"
  , package "base" "4.3.1.0"
  , package "bin-package-db" "0.0.0.0"
  , package "bytestring" "0.9.1.10"
  , package "containers" "0.4.0.0"
  , package "directory" "1.1.0.0"
  , package "extensible-exceptions" "0.1.1.2"
  , package "ffi" "1.0"
  , package "filepath" "1.2.0.0"
  , Package "ghc" "7.0.3" Hidden
  , Package "ghc-binary" "0.5.0.2" Hidden
  , package "ghc-prim" "0.2.0.0"
  , Package "haskell2010" "1.0.0.0" Hidden
  , package "haskell98" "1.1.0.1"
  , package "hpc" "0.5.0.6"
  , package "integer-gmp" "0.2.0.3"
  , package "old-locale" "1.0.0.2"
  , package "old-time" "1.0.0.6"
  , package "pretty" "1.0.1.2"
  , package "process" "1.0.1.5"
  , package "random" "1.0.0.3"
  , package "rts" "1.0"
  , package "template-haskell" "2.5.0.0"
  , package "time" "1.2.0.3"
  , package "unix" "2.4.2.0"
  ]

hp_2011_2_0_1 :: [Package]
hp_2011_2_0_1 = [
    package "GLUT" "2.1.2.1"
  , package "HTTP" "4000.1.1"
  , package "HUnit" "1.2.2.3"
  , package "OpenGL" "2.2.3.0"
  , package "QuickCheck" "2.4.0.1"
  , package "cgi" "3001.1.7.4"
  , package "deepseq" "1.1.0.2"
  , package "fgl" "5.4.2.3"
  , package "haskell-platform" "2011.2.0.1"
  , package "haskell-src" "1.0.1.4"
  , package "html" "1.0.1.2"
  , package "mtl" "2.0.1.0"
  , package "network" "2.3.0.2"
  , package "parallel" "3.1.0.1"
  , package "parsec" "3.1.1"
  , package "regex-base" "0.93.2"
  , package "regex-compat" "0.93.1"
  , package "regex-posix" "0.94.4"
  , package "stm" "2.2.0.1"
  , package "syb" "0.3"
  , package "text" "0.11.0.6"
  , package "transformers" "0.2.2.0"
  , package "xhtml" "3000.2.0.1"
  , package "zlib" "0.5.3.1"
  ]

ghc_7_0_2 :: [Package]
ghc_7_0_2 = [
    package "Cabal" "1.10.1.0"
  , package "array" "0.3.0.2"
  , package "base" "4.3.1.0"
  , package "bin-package-db" "0.0.0.0"
  , package "bytestring" "0.9.1.10"
  , package "containers" "0.4.0.0"
  , package "directory" "1.1.0.0"
  , package "extensible-exceptions" "0.1.1.2"
  , package "ffi" "1.0"
  , package "filepath" "1.2.0.0"
  , Package "ghc" "7.0.2" Hidden
  , Package "ghc-binary" "0.5.0.2" Hidden
  , package "ghc-prim" "0.2.0.0"
  , Package "haskell2010" "1.0.0.0" Hidden
  , package "haskell98" "1.1.0.1"
  , package "hpc" "0.5.0.6"
  , package "integer-gmp" "0.2.0.3"
  , package "old-locale" "1.0.0.2"
  , package "old-time" "1.0.0.6"
  , package "pretty" "1.0.1.2"
  , package "process" "1.0.1.5"
  , package "random" "1.0.0.3"
  , package "rts" "1.0"
  , package "template-haskell" "2.5.0.0"
  , package "time" "1.2.0.3"
  , package "unix" "2.4.2.0"
  ]

hp_2011_2_0_0 :: [Package]
hp_2011_2_0_0 = [
    package "GLUT" "2.1.2.1"
  , package "HTTP" "4000.1.1"
  , package "HUnit" "1.2.2.3"
  , package "OpenGL" "2.2.3.0"
  , package "QuickCheck" "2.4.0.1"
  , package "cgi" "3001.1.7.4"
  , package "deepseq" "1.1.0.2"
  , package "fgl" "5.4.2.3"
  , package "haskell-platform" "2011.2.0.0"
  , package "haskell-src" "1.0.1.4"
  , package "html" "1.0.1.2"
  , package "mtl" "2.0.1.0"
  , package "network" "2.3.0.2"
  , package "parallel" "3.1.0.1"
  , package "parsec" "3.1.1"
  , package "regex-base" "0.93.2"
  , package "regex-compat" "0.93.1"
  , package "regex-posix" "0.94.4"
  , package "stm" "2.2.0.1"
  , package "syb" "0.3"
  , package "text" "0.11.0.5"
  , package "transformers" "0.2.2.0"
  , package "xhtml" "3000.2.0.1"
  , package "zlib" "0.5.3.1"
  ]

ghc_6_12_3 :: [Package]
ghc_6_12_3 = [
    package "Cabal" "1.8.0.6"
  , package "array" "0.3.0.1"
  , package "base" "3.0.3.2"
  , package "base" "4.2.0.2"
  , package "bin-package-db" "0.0.0.0"
  , package "bytestring" "0.9.1.7"
  , package "containers" "0.3.0.0"
  , package "directory" "1.0.1.1"
  , Package "dph-base" "0.4.0" Hidden
  , Package "dph-par" "0.4.0" Hidden
  , Package "dph-prim-interface" "0.4.0" Hidden
  , Package "dph-prim-par" "0.4.0" Hidden
  , Package "dph-prim-seq" "0.4.0" Hidden
  , Package "dph-seq" "0.4.0" Hidden
  , package "extensible-exceptions" "0.1.1.1"
  , package "ffi" "1.0"
  , package "filepath" "1.1.0.4"
  , Package "ghc" "6.12.3" Hidden
  , Package "ghc-binary" "0.5.0.2" Hidden
  , package "ghc-prim" "0.2.0.0"
  , package "haskell98" "1.0.1.1"
  , package "hpc" "0.5.0.5"
  , package "integer-gmp" "0.2.0.1"
  , package "old-locale" "1.0.0.2"
  , package "old-time" "1.0.0.5"
  , package "pretty" "1.0.1.1"
  , package "process" "1.0.1.3"
  , package "random" "1.0.0.2"
  , package "rts" "1.0"
  , package "syb" "0.1.0.2"
  , package "template-haskell" "2.4.0.1"
  , package "time" "1.1.4"
  , package "unix" "2.4.0.2"
  ]

hp_2010_2_0_0 :: [Package]
hp_2010_2_0_0 = [
    package "GLUT" "2.1.2.1"
  , package "HTTP" "4000.0.9"
  , package "HUnit" "1.2.2.1"
  , package "OpenGL" "2.2.3.0"
  , package "QuickCheck" "2.1.1.1"
  , package "cgi" "3001.1.7.3"
  , package "deepseq" "1.1.0.0"
  , package "fgl" "5.4.2.3"
  , package "haskell-platform" "2010.2.0.0"
  , package "haskell-src" "1.0.1.3"
  , package "html" "1.0.1.2"
  , package "mtl" "1.1.0.2"
  , package "network" "2.2.1.7"
  , package "parallel" "2.2.0.1"
  , package "parsec" "2.1.0.1"
  , package "regex-base" "0.93.2"
  , package "regex-compat" "0.93.1"
  , package "regex-posix" "0.94.2"
  , package "stm" "2.1.2.1"
  , package "xhtml" "3000.2.0.1"
  , package "zlib" "0.5.2.0"
  ]
