{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}

module Servant.Checked.Exceptions.Internal.Envelope where

import Control.Applicative ((<|>))
import Data.Aeson
       (FromJSON(parseJSON), ToJSON(toJSON), Value, (.=), (.:), object, withObject)
import Data.Aeson.Types (Parser)
import Data.Data (Data)
import Data.Typeable (Typeable)
import GHC.Generics (Generic)

import Servant.Checked.Exceptions.Internal.Union (IsMember, OpenUnion, openUnionLift)

data Envelope es a = ErrEnvelope (OpenUnion es) | SuccEnvelope a
  deriving (Foldable, Functor, Generic, Traversable)

toErrEnvelope :: IsMember e es => e -> Envelope es a
toErrEnvelope = ErrEnvelope . openUnionLift

toSuccEnvelope :: a -> Envelope es a
toSuccEnvelope = SuccEnvelope

pureErrEnvelope :: (Applicative m, IsMember e es) => e -> m (Envelope es a)
pureErrEnvelope = pure . toErrEnvelope

pureSuccEnvelope :: Applicative m => a -> m (Envelope es a)
pureSuccEnvelope = pure . toSuccEnvelope

instance (ToJSON (OpenUnion es), ToJSON a) => ToJSON (Envelope es a) where
  toJSON :: Envelope es a -> Value
  toJSON (ErrEnvelope es) = object ["err" .= es]
  toJSON (SuccEnvelope a) = object ["data" .= a]

instance (FromJSON (OpenUnion es), FromJSON a) => FromJSON (Envelope es a) where
  parseJSON :: Value -> Parser (Envelope es a)
  parseJSON = withObject "Envelope" $ \obj ->
    SuccEnvelope <$> obj .: "data" <|>
    ErrEnvelope <$> obj .: "err"

deriving instance (Data (OpenUnion es), Data a, Typeable es) => Data (Envelope es a)
deriving instance (Eq (OpenUnion es), Eq a) => Eq (Envelope es a)
deriving instance (Ord (OpenUnion es), Ord a) => Ord (Envelope es a)
deriving instance (Read (OpenUnion es), Read a) => Read (Envelope es a)
deriving instance (Typeable (OpenUnion es), Typeable a) => Typeable (Envelope es a)

instance Applicative (Envelope es) where
  pure :: a -> Envelope es a
  pure = SuccEnvelope

  (<*>) :: Envelope es (a -> b) -> Envelope es a -> Envelope es b
  ErrEnvelope es <*> _ = ErrEnvelope es
  SuccEnvelope f <*> r = fmap f r

instance Monad (Envelope e) where
  (>>=) :: Envelope es a -> (a -> Envelope es b) -> Envelope es b
  ErrEnvelope l >>= _ = ErrEnvelope l
  SuccEnvelope r >>= k = k r