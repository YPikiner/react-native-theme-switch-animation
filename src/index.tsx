import {
  NativeModules,
  Platform,
  NativeEventEmitter,
  Dimensions,
} from 'react-native';

const { width, height } = Dimensions.get('screen');

const LINKING_ERROR =
  `The package 'react-native-theme-switch-animation' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const ThemeSwitchAnimation = NativeModules.ThemeSwitchAnimationModule
  ? NativeModules.ThemeSwitchAnimationModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

type CircularAnimationType = 'circular' | 'inverted-circular';

type CircularAnimationConfig = {
  type: CircularAnimationType;
  duration: number;
  cxRatio: number;
  cyRatio: number;
};

type CircularAnimationConfigExact = {
  type: CircularAnimationType;
  duration: number;
  cx: number;
  cy: number;
};

type FadeAnimationConfig = {
  type: 'fade';
  duration: number;
};

type AnimationConfig =
  | CircularAnimationConfig
  | FadeAnimationConfig
  | CircularAnimationConfigExact;

type ThemeSwitcherHookProps = {
  switchThemeFunction: () => void;
  animationConfig?: AnimationConfig;
};

let switchFunction: () => void = () => {};
let localAnimationConfig: AnimationConfig = {
  type: 'fade',
  duration: 500,
};

new NativeEventEmitter(NativeModules.ThemeSwitchAnimationModule).addListener(
  'FINISHED_FREEZING_SCREEN',
  () => {
    setTimeout(() => {
      if (switchFunction) {
        switchFunction();
        if (localAnimationConfig) {
          unfreezeWrapper();
        }
      }
    });
  }
);

const switchTheme = ({
  switchThemeFunction: incomingSwithThemeFunction,
  animationConfig,
}: ThemeSwitcherHookProps) => {
  localAnimationConfig = animationConfig || localAnimationConfig;
  ThemeSwitchAnimation.freezeScreen();
  switchFunction = incomingSwithThemeFunction;
};

const validateCoordinates = (value: number, max: number, name: string) => {
  if (value === undefined) {
    throw new Error(`${name} is undefined. Please provide both cx and cy.`);
  }
  if (value > max) {
    throw new Error(
      `${name} is greater than ${max}. Please provide a ${name} smaller than screen size.`
    );
  }
  if (value < -max) {
    throw new Error(
      `${name} is smaller than -${max}. Please provide a ${name} bigger than -screen size.`
    );
  }
};

const calculateRatio = (value: number, max: number) => {
  return value > 0 ? value / max : 1 + value / max;
};

const calculateActualRation = (ration: number) => {
  return ration > 0 ? ration : 1 + ration;
};

const unfreezeWrapper = () => {
  const defaultRatio = 0.5;
  setImmediate(() => {
    if (
      localAnimationConfig.type === 'circular' ||
      localAnimationConfig.type === 'inverted-circular'
    ) {
      if ('cx' in localAnimationConfig && 'cy' in localAnimationConfig) {
        const { cx, cy } = localAnimationConfig as CircularAnimationConfigExact;

        validateCoordinates(cx, width, 'cx');
        validateCoordinates(cy, height, 'cy');

        const cxRatio = calculateRatio(cx, width);
        const cyRatio = calculateRatio(cy, height);

        ThemeSwitchAnimation.unfreezeScreen(
          localAnimationConfig.type,
          localAnimationConfig.duration,
          cxRatio,
          cyRatio
        );
      } else if (
        'cxRatio' in localAnimationConfig &&
        'cyRatio' in localAnimationConfig
      ) {
        // Assuming 'cxRatio' and 'cyRatio' are part of CircularAnimationConfig
        const { cxRatio, cyRatio } =
          localAnimationConfig as CircularAnimationConfig;

        validateCoordinates(cxRatio, 1, 'cxRatio');
        validateCoordinates(cyRatio, 1, 'cyRatio');

        const cxRatioActual = calculateActualRation(cxRatio);
        const cyRatioActual = calculateActualRation(cyRatio);

        ThemeSwitchAnimation.unfreezeScreen(
          localAnimationConfig.type,
          localAnimationConfig.duration,
          cxRatioActual,
          cyRatioActual
        );
      }
    } else {
      ThemeSwitchAnimation.unfreezeScreen(
        localAnimationConfig.type,
        localAnimationConfig.duration,
        defaultRatio,
        defaultRatio
      );
    }
  });
};

export default switchTheme;
