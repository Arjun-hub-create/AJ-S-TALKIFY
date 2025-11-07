// Password Strength Validator
// Visual indicator for password strength

class PasswordStrengthValidator {
    constructor() {
        this.init();
    }

    init() {
        // Find password inputs on signup form
        const signupPassword = document.getElementById('signup-password');
        const confirmPassword = document.getElementById('signup-confirm-password');

        if (signupPassword) {
            this.addStrengthIndicator(signupPassword);
            
            signupPassword.addEventListener('input', (e) => {
                this.updateStrength(e.target);
            });
        }

        if (confirmPassword) {
            confirmPassword.addEventListener('input', () => {
                this.validateMatch(signupPassword, confirmPassword);
            });

            signupPassword.addEventListener('input', () => {
                if (confirmPassword.value) {
                    this.validateMatch(signupPassword, confirmPassword);
                }
            });
        }
    }

    addStrengthIndicator(input) {
        const wrapper = input.closest('.input-wrapper');
        if (!wrapper || wrapper.querySelector('.password-strength')) return;

        const indicator = document.createElement('div');
        indicator.className = 'password-strength';
        indicator.innerHTML = `
            <div class="strength-bar">
                <div class="strength-fill"></div>
            </div>
            <div class="strength-text">Password strength: <span class="strength-level">-</span></div>
            <ul class="strength-requirements">
                <li data-req="length"><i class="fas fa-circle"></i> At least 8 characters</li>
                <li data-req="lowercase"><i class="fas fa-circle"></i> One lowercase letter</li>
                <li data-req="uppercase"><i class="fas fa-circle"></i> One uppercase letter</li>
                <li data-req="number"><i class="fas fa-circle"></i> One number</li>
                <li data-req="special"><i class="fas fa-circle"></i> One special character</li>
            </ul>
        `;

        wrapper.appendChild(indicator);
    }

    calculateStrength(password) {
        let strength = 0;
        const requirements = {
            length: password.length >= 8,
            lowercase: /[a-z]/.test(password),
            uppercase: /[A-Z]/.test(password),
            number: /[0-9]/.test(password),
            special: /[^A-Za-z0-9]/.test(password)
        };

        // Calculate strength score
        Object.values(requirements).forEach(met => {
            if (met) strength++;
        });

        let level = 'weak';
        let percentage = 0;

        if (strength === 0) {
            level = 'none';
            percentage = 0;
        } else if (strength <= 2) {
            level = 'weak';
            percentage = 20;
        } else if (strength === 3) {
            level = 'fair';
            percentage = 50;
        } else if (strength === 4) {
            level = 'good';
            percentage = 75;
        } else {
            level = 'strong';
            percentage = 100;
        }

        return { strength, level, percentage, requirements };
    }

    updateStrength(input) {
        const password = input.value;
        const wrapper = input.closest('.input-wrapper');
        const indicator = wrapper.querySelector('.password-strength');
        
        if (!indicator) return;

        const { level, percentage, requirements } = this.calculateStrength(password);

        // Update bar
        const fill = indicator.querySelector('.strength-fill');
        fill.style.width = `${percentage}%`;
        fill.className = `strength-fill strength-${level}`;

        // Update text
        const levelText = indicator.querySelector('.strength-level');
        levelText.textContent = level === 'none' ? '-' : level.charAt(0).toUpperCase() + level.slice(1);
        levelText.className = `strength-level strength-${level}`;

        // Update requirements
        Object.keys(requirements).forEach(req => {
            const reqItem = indicator.querySelector(`[data-req="${req}"]`);
            if (reqItem) {
                if (requirements[req]) {
                    reqItem.classList.add('met');
                    reqItem.querySelector('i').className = 'fas fa-check-circle';
                } else {
                    reqItem.classList.remove('met');
                    reqItem.querySelector('i').className = 'fas fa-circle';
                }
            }
        });

        // Show/hide indicator
        if (password.length > 0) {
            indicator.style.display = 'block';
        } else {
            indicator.style.display = 'none';
        }
    }

    validateMatch(password, confirmPassword) {
        const wrapper = confirmPassword.closest('.input-wrapper');
        let matchIndicator = wrapper.querySelector('.password-match');

        if (!matchIndicator) {
            matchIndicator = document.createElement('div');
            matchIndicator.className = 'password-match';
            wrapper.appendChild(matchIndicator);
        }

        if (confirmPassword.value.length === 0) {
            matchIndicator.style.display = 'none';
            return;
        }

        matchIndicator.style.display = 'block';

        if (password.value === confirmPassword.value) {
            matchIndicator.innerHTML = '<i class="fas fa-check-circle"></i> Passwords match';
            matchIndicator.className = 'password-match match-success';
        } else {
            matchIndicator.innerHTML = '<i class="fas fa-times-circle"></i> Passwords do not match';
            matchIndicator.className = 'password-match match-error';
        }
    }

    isPasswordStrong(password) {
        const { strength } = this.calculateStrength(password);
        return strength >= 4; // At least 4 out of 5 requirements
    }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.passwordValidator = new PasswordStrengthValidator();
    });
} else {
    window.passwordValidator = new PasswordStrengthValidator();
}
