import SwiftUI
import FinancesCore

struct WelcomeView: View {
    let onFinish: (_ loadDemo: Bool) -> Void

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.indigo, .purple, .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: .indigo.opacity(0.35), radius: 18, y: 8)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Финансы")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Доходы, обязательные платежи и подписки — в одном месте")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                feature(
                    icon: "banknote.fill",
                    tint: .green,
                    title: "Выплаты с типами",
                    text:
                        "Зарплата, аванс, отпускные, премия, больничный. Средние значения и итоги по годам и кварталам."
                )
                feature(
                    icon: "building.2.fill",
                    tint: .blue,
                    title: "Квартира, гараж, коммуналка",
                    text: "Регулярные платежи с правилами округления: видно базовую сумму, надбавку и итог к оплате."
                )
                feature(
                    icon: "repeat.circle.fill",
                    tint: .purple,
                    title: "Подписки и аналитика",
                    text: "Сколько сервисы съедают в месяц и в год. Графики, бублики и фильтры по категориям."
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Button("Начать с нуля") {
                    onFinish(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Загрузить демо-данные") {
                    onFinish(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }

            Text("Всё хранится локально на этом Mac. Демо-данные можно удалить в настройках.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 560)
        .background(.regularMaterial)
    }

    private func feature(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
