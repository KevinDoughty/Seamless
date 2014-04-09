## Seamless

`Seamless.framework` for OSX and `libSeamless.a` for iOS enhance Core Animation with additive negative delta animation.
It adds simple animation smoothing or custom timing determined by blocks, 
to instances of `CABasicAnimation` with an extension to `CATransaction`,
or on instances of a `CABasicAnimation` subclass called `SeamlessAnimation`.
It is meant to be used where implicit animation is appropriate,
and is especially useful for the `NSAnimatablePropertyContainer` Protocol (`NSView` animation) which requires implicit animation.
Animations are declared with absolute values, 
but run relative to the underlying model value by animating from the old model value minus the new model value, 
to a destination value of zero.
Animating relatively is the best technique for responding to rapid user events.
Unfortunately there are bugs in Core Animation that reduce usefulness,
the most significant being rdar://problem/12085417 which breaks additive opacity animation.


### `CATransaction`

#### `+(void)setSeamlessNegativeDelta:(BOOL)theSeamless`

Uses additive,
enables negative delta animation, 
uses previous values instead of presentation,
uses fillMode of kCAFillModeBackwards,
affects animation key naming behavior,

#### `+(void)setSeamlessSteps:(NSUInteger))theSteps`

Keyframes are used to emulate a custom timing function.
Without timing block this has no effect.
If not set, default is 100.

#### `+(void)setSeamlessTimingBlock:(double(^)(double))theBlock;`

Set the block used for timing of animations in current transaction. 
Sole argument is a `double` between 0 and 1.
Return value is a `double` that can also be below 0 and above 1.
If not set, animations use a `CAMediaTimingFunction` with control points 0.5, 0.0, 0.5, 1.0 for simple smoothing.
Additive or negative delta behavior is not implied or required with this.

##### Discussion

Timing is emulated by replacing animations with instances of CAKeyframeAnimation behind the scenes.
Animated values must be one of transform, rect, size, point, float, or double.

##### Example

This gives a nice elastic wobble and is based on math from Matt Gallager's excellent [Animation Acceleration](http://www.cocoawithlove.com/2008/09/parametric-acceleration-curves-in-core.html).

```objc
[CATransaction setAnimationDuration:3.0];
[CATransaction setSeamlessNegativeDelta:YES];
[CATransaction setSeamlessTimingBlock:^ (double progress) {
	double omega = 20.0;
	double zeta = 0.5;
	double beta = sqrt(1.0 - zeta * zeta);
	return 1 - 1 / beta * expf(-zeta * omega * progress) * sinf(beta * omega * progress + atanf(beta / zeta));
}];
theFirstLayer.position = CGPointMake(100,100);
theSecondLayer.transform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
```

#### `+(void)setSeamlessKeyBehavior:(SeamlessKeyBehavior)theBehavior;`

This determines what key is used when adding animations in -addAnimation:forKey:.
OSX animation using the NSAnimatablePropertyContainer protocol's view animator 
will by default use the animated property as the key,
which only allows a single animation to run at a time for any given property.
To run many additive animations on the same property, a nil or unique key is required.

##### Discussion

A useful technique is copying animations from one layer and applying them to newly inserted layers, to keep animated content in sync.
Otherwise it would be difficult to reproduce existing animations triggered by user interaction.
In this case a unique key is needed to recall animations using -animationKeys and -animationForKey:.

#### `typedef enum SeamlessKeyBehavior`

##### `seamlessKeyDefault`

If seamlessNegativeDelta == YES this will use a nil key, 
otherwise it will respect default Core Animation behavior of using the exact key as passed.

##### `seamlessKeyExact`

Use the exact key as passed to addAnimation:forKey: 
(Useful if you have your own scheme for creating unique keys, for recalling them, most likely to copy animations.)
    
##### `seamlessKeyNil`

Use a nil key regardless of what was passed in addAnimation:forKey:

##### `seamlessKeyIncrement`

Deprecated. Just a string representation of an incremented integer. 
The key passed to addAnimation:forKey: is ignored.

##### `seamlessKeyIncrementKey`

The used key becomes the key passed to addAnimation:forKey: 
plus an appended string representation of an incremented integer.
If the key passed in addAnimation:forKey: is nil you get just the integer.

##### `seamlessKeyIncrementKeyPath`

The used key becomes the animated key path plus an appended string representation of an incremented integer.

#### `typedef double(^SeamlessTimingBlock)(double);`

A convenience typedef for difficult block syntax.

### `CABasicAnimation`

#### `-(void)setSeamlessNegativeDelta:(BOOL)theSeamless`

Overrides transaction value, with the same effect.

#### `-(void)setSeamlessSteps:(NSUInteger))theSteps`

Overrides transaction value, with the same effect.

#### `-(void)setSeamlessTimingBlock:(double (^)(double))theBlock;`

Overrides transaction value, with the same effect.

#### `-(void)setSeamlessKeyBehavior:(SeamlessKeyBehavior)theBehavior;`

Overrides transaction value, with the same effect.

### `NSAnimationContext`

#### `-(void)setSeamlessNegativeDelta:(BOOL)theSeamless`

Passes message to CATransaction.

#### `-(void)setSeamlessSteps:(NSUInteger))theSteps`

Passes message to CATransaction.

#### `-(void)setSeamlessTimingBlock:(double (^)(double))theBlock;`

Passes message to CATransaction.

#### `-(void)setSeamlessKeyBehavior:(SeamlessKeyBehavior)theBehavior;`

Passes message to CATransaction.

### `SeamlessAnimation`

Subclass of `CABasicAnimation`. 
Default values differ from CABasicAnimation:
additive = YES, 
fillMode = kCAFillModeBackwards, 
seamlessNegativeDelta = YES,
keyNamingBehavior = seamlessKeyDefault

#### `@property (copy) id oldValue;`

Optional. The layer's previous model value or what it is supposed to appear to be. 
You define the value absolutely but behind the scenes it is converted to a relative old minus new.
If unset, the layer's previous model value is used.

#### `@property (copy) id nuValue;`

Optional. The layer's current ("new") model value or what it is supposed to appear to be.
Behind the scenes, the actual animation destination is zero.

## Examples

### Simple Seamless

The most basic example for OSX animation.
It is a from scratch re-implementation of "Follow Me" by Matt Long 10/22/08,
which is an great example of presentation layer animation behavior.
Drag the mouse cursor around the window and the dot will follow.

### CocoaSlides

This is an old Apple sample project from 10.5 Leopard, updated to use the Seamless.framework.
Minor changes were made to make the window resizable, to flip view coordinates,
and to the layout algorithm for allowing narrow widths.
The significant code is in `AssetCollectionView` method `-(void)layoutSubviews`,
which merely sets seamlessNegativeDelta to YES and assigns a timing block.
Try resizing the window or hitting command-1 through command-4.

### JellyBeans

This is sample code showing an animated grid in a layer hosting view.
It will probably be removed in the future.

### Touches_GestureRecognizers

An example of relative animation on iOS, modified from original Apple sample code.
The gesture recognizer IBActions in `APLViewController` were modified.
SeamlessAnimations are created and views are explicitly animated,
which is to date the only success I've had with this technique.
There is some discrepancy with scaling, particularly in the presence of rotation.
But it is still noticeable even when all animation is disabled by setting `static BOOL const useSeamlessAnimation` to NO. 

## License

Released under the [BSD License](http://www.opensource.org/licenses/bsd-license).
Inslerpolate.c is adapted from WebKit source and released under a separate license.

## TODO:

Documentation needs refining.

Need better iOS examples.
