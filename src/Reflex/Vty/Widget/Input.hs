{-|
Module: Reflex.Vty.Widget.Input
Description: User input widgets for reflex-vty
-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Reflex.Vty.Widget.Input
  ( module Export
  , module Reflex.Vty.Widget.Input
  ) where


import Reflex.Vty.Widget.Input.Text as Export

import Control.Monad (join)
import Control.Monad.Fix (MonadFix)
import Control.Monad.NodeId (MonadNodeId)
import Data.Default (Default(..))
import Data.Text (Text)
import qualified Graphics.Vty as V
import Reflex
import Reflex.Vty.Widget

-- | Configuration options for the 'button' widget
data ButtonConfig t = ButtonConfig
  { _buttonConfig_boxStyle :: Behavior t BoxStyle
  , _buttonConfig_focusStyle :: Behavior t BoxStyle
  }

instance Reflex t => Default (ButtonConfig t) where
  def = ButtonConfig (pure singleBoxStyle) (pure thickBoxStyle)

-- | A button widget that contains a sub-widget
button
  :: (Reflex t, Monad m, MonadNodeId m)
  => ButtonConfig t
  -> VtyWidget t m ()
  -> VtyWidget t m (Event t ())
button cfg child = do
  f <- focus
  let style = do
        isFocused <- current f
        if isFocused
          then _buttonConfig_focusStyle cfg
          else _buttonConfig_boxStyle cfg
  box style child
  m <- mouseUp
  k <- key V.KEnter
  return $ leftmost [() <$ k, () <$ m]

-- | A button widget that displays text that can change
textButton
  :: (Reflex t, Monad m, MonadNodeId m)
  => ButtonConfig t
  -> Behavior t Text
  -> VtyWidget t m (Event t ())
textButton cfg = button cfg . text -- TODO Centering etc.

-- | A button widget that displays a static bit of text
textButtonStatic
  :: (Reflex t, Monad m, MonadNodeId m)
  => ButtonConfig t
  -> Text
  -> VtyWidget t m (Event t ())
textButtonStatic cfg = textButton cfg . pure

-- | A clickable link widget
link
  :: (Reflex t, Monad m)
  => Behavior t Text
  -> VtyWidget t m (Event t MouseUp)
link t = do
  defTheme <- defaultTheme
  let cfg = RichTextConfig
        { _richTextConfig_attributes = fmap (\attr -> V.withStyle attr V.underline) defTheme
        }
  richText cfg t
  mouseUp

-- | A clickable link widget with a static label
linkStatic
  :: (Reflex t, Monad m)
  => Text
  -> VtyWidget t m (Event t MouseUp)
linkStatic = link . pure

-- | Characters used to render checked and unchecked textboxes
data CheckboxStyle = CheckboxStyle
  { _checkboxStyle_unchecked :: Text
  , _checkboxStyle_checked :: Text
  }

instance Default CheckboxStyle where
  def = checkboxStyleTick

-- | This checkbox style uses an "x" to indicate the checked state
checkboxStyleX :: CheckboxStyle
checkboxStyleX = CheckboxStyle
  { _checkboxStyle_unchecked = "[ ]"
  , _checkboxStyle_checked = "[x]"
  }

-- | This checkbox style uses a unicode tick mark to indicate the checked state
checkboxStyleTick :: CheckboxStyle
checkboxStyleTick = CheckboxStyle
  { _checkboxStyle_unchecked = "[ ]"
  , _checkboxStyle_checked = "[✓]"
  }

-- | Configuration options for a checkbox
data CheckboxConfig t = CheckboxConfig
  { _checkboxConfig_checkboxStyle :: Behavior t CheckboxStyle
  -- TODO change to (Maybe Behavior t V.Attr)
  , _checkboxConfig_attributes :: Behavior t V.Attr
  }

instance (Reflex t) => Default (CheckboxConfig t) where
  def = CheckboxConfig
    { _checkboxConfig_checkboxStyle = pure def
    , _checkboxConfig_attributes = pure V.defAttr
    }

-- | A checkbox widget
checkbox
  :: (MonadHold t m, MonadFix m, Reflex t)
  => CheckboxConfig t
  -> Bool
  -> VtyWidget t m (Dynamic t Bool)
checkbox cfg v0 = do
  md <- mouseDown V.BLeft
  mu <- mouseUp
  v <- toggle v0 $ () <$ mu
  depressed <- hold mempty $ leftmost
    [ V.withStyle mempty V.bold <$ md
    , mempty <$ mu
    ]
  let attrs = (<>) <$> (_checkboxConfig_attributes cfg) <*> depressed
  richText (RichTextConfig attrs) $ join . current $ ffor v $ \checked ->
    if checked
      then fmap _checkboxStyle_checked $ _checkboxConfig_checkboxStyle cfg
      else fmap _checkboxStyle_unchecked $ _checkboxConfig_checkboxStyle cfg
  return v
