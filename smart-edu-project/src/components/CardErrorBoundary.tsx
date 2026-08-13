import React, { Component, ErrorInfo, ReactNode } from 'react';

interface CardErrorBoundaryProps {
  children: ReactNode;
  label?: string;
}

interface CardErrorBoundaryState {
  hasError: boolean;
}

/**
 * Keeps one broken interactive card from unmounting the whole student portal.
 * The retry is local to the card, so role/session state is never touched.
 */
class CardErrorBoundary extends Component<CardErrorBoundaryProps, CardErrorBoundaryState> {
  state: CardErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): CardErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error(`[card] ${this.props.label || 'interactive card'} render error:`, error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false });
  };

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <div
        dir="rtl"
        role="alert"
        className="flex min-h-40 h-full flex-col items-center justify-center gap-3 rounded-[28px] border border-amber-300/30 bg-slate-950/90 p-5 text-center text-white shadow-xl"
      >
        <span className="text-4xl" aria-hidden="true">🛟</span>
        <p className="text-sm font-black">تعذر تحميل هذه البطاقة مؤقتًا</p>
        <button
          type="button"
          onClick={this.handleRetry}
          className="rounded-xl bg-cyan-400 px-4 py-2 text-xs font-black text-slate-950 transition hover:bg-cyan-300 focus:outline-none focus:ring-4 focus:ring-cyan-200/40"
        >
          إعادة المحاولة
        </button>
      </div>
    );
  }
}

export default CardErrorBoundary;