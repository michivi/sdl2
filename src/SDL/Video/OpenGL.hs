{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
module SDL.Video.OpenGL
  ( -- * OpenGL
    defaultOpenGL
  , OpenGLConfig(..)
  , GLContext
  , glCreateContext
  , Profile(..)
  , Mode(..)
  , glMakeCurrent
  , glDeleteContext

  , glSwapWindow
  , SwapInterval(..)
  , swapInterval

  -- ** Function Loading
  , Raw.glGetProcAddress
  ) where

import Control.Applicative
import Control.Monad.IO.Class (MonadIO)
import Data.Data (Data)
import Data.StateVar
import Data.Typeable
import Foreign.C.Types
import GHC.Generics (Generic)
import Linear
import SDL.Exception
import SDL.Internal.Numbered
import SDL.Internal.Types

import qualified SDL.Raw as Raw

-- | A set of default options for 'OpenGLConfig'
--
-- @
-- 'defaultOpenGL' = 'OpenGLConfig'
--   { 'glColorPrecision' = V4 8 8 8 0
--   , 'glDepthPrecision' = 24
--   , 'glStencilPrecision' = 8
--   , 'glProfile' = 'Compatibility' 'Normal' 2 1
--   }
--_@
defaultOpenGL :: OpenGLConfig
defaultOpenGL = OpenGLConfig
  { glColorPrecision = V4 8 8 8 0
  , glDepthPrecision = 24
  , glStencilPrecision = 8
  , glProfile = Compatibility Normal 2 1
  }

-- | Configuration used when creating an OpenGL rendering context.
data OpenGLConfig = OpenGLConfig
  { glColorPrecision   :: V4 CInt -- ^ Defaults to 'V4' @8 8 8 0@.
  , glDepthPrecision   :: CInt    -- ^ Defaults to @24@.
  , glStencilPrecision :: CInt    -- ^ Defaults to @8@.
  , glProfile          :: Profile -- ^ Defaults to 'Compatibility' 'Normal' @2 1@.
  } deriving (Eq, Generic, Ord, Read, Show, Typeable)

data Profile
  = Core Mode CInt CInt
    -- ^ Use the OpenGL core profile, with a given major and minor version
  | Compatibility Mode CInt CInt
    -- ^ Use the compatibilty profile with a given major and minor version. The compatibility profile allows you to use deprecated functions such as immediate mode
  | ES Mode CInt CInt
    -- ^ Use an OpenGL profile for embedded systems
  deriving (Eq, Generic, Ord, Read, Show, Typeable)

data Mode
  = Normal
    -- ^ A normal profile with no special debugging support
  | Debug
    -- ^ Use a debug context, allowing the usage of extensions such as @GL_ARB_debug_output@
  deriving (Bounded, Data, Enum, Eq, Generic, Ord, Read, Show, Typeable)

newtype GLContext = GLContext Raw.GLContext
  deriving (Eq, Typeable)

-- | Create a new OpenGL context and makes it the current context for the
-- window.
--
-- Throws 'SDLException' if the window wasn't configured with OpenGL
-- support, or if context creation fails.
glCreateContext :: (Functor m, MonadIO m) => Window -> m GLContext
glCreateContext (Window w) =
  GLContext <$> throwIfNull "SDL.Video.glCreateContext" "SDL_GL_CreateContext"
    (Raw.glCreateContext w)

-- | Throws 'SDLException' on failure.
glMakeCurrent :: (Functor m, MonadIO m) => Window -> GLContext -> m ()
glMakeCurrent (Window w) (GLContext ctx) =
  throwIfNeg_ "SDL.Video.OpenGL.glMakeCurrent" "SDL_GL_MakeCurrent" $
    Raw.glMakeCurrent w ctx

-- | Delete the given OpenGL context.
--
-- You /must/ make sure that there are no pending commands in the OpenGL
-- command queue, the driver may still be processing commands even if you have
-- stopped issuing them!
--
-- The @glFinish@ command will block until the command queue has been fully
-- processed. You should call that function before deleting a context.
glDeleteContext :: MonadIO m => GLContext -> m ()
glDeleteContext (GLContext ctx) = Raw.glDeleteContext ctx

-- | Replace the contents of the front buffer with the back buffer's. The
-- contents of the back buffer are undefined, clear them with @glClear@ or
-- equivalent before drawing to them again.
glSwapWindow :: MonadIO m => Window -> m ()
glSwapWindow (Window w) = Raw.glSwapWindow w

-- | The swap interval for the current OpenGL context.
data SwapInterval
  = ImmediateUpdates
    -- ^ No vertical retrace synchronization
  | SynchronizedUpdates
    -- ^ The buffer swap is synchronized with the vertical retrace
  | LateSwapTearing
  deriving (Bounded, Data, Enum, Eq, Generic, Ord, Read, Show, Typeable)

instance ToNumber SwapInterval CInt where
  toNumber ImmediateUpdates = 0
  toNumber SynchronizedUpdates = 1
  toNumber LateSwapTearing = -1

instance FromNumber SwapInterval CInt where
  fromNumber n' =
    case n' of
      0 -> ImmediateUpdates
      1 -> SynchronizedUpdates
      -1 -> LateSwapTearing
      _ ->
        error ("Unknown SwapInterval: " ++ show n')

-- | Get or set the swap interval for the current OpenGL context.
--
-- This 'StateVar' can be modified using '$=' and the current value retrieved with 'get'.
--
-- See @<https://wiki.libsdl.org/SDL_GL_SetSwapInterval SDL_GL_SetSwapInterval>@ and @<https://wiki.libsdl.org/SDL_GL_GetSwapInterval SDL_GL_GetSwapInterval>@ for C documentation.
swapInterval :: StateVar SwapInterval
swapInterval = makeStateVar glGetSwapInterval glSetSwapInterval
  where
  glGetSwapInterval = fmap fromNumber $ Raw.glGetSwapInterval


  glSetSwapInterval swapInterval =
    throwIfNeg_ "SDL.Video.glSetSwapInterval" "SDL_GL_SetSwapInterval" $
      Raw.glSetSwapInterval (toNumber swapInterval)
