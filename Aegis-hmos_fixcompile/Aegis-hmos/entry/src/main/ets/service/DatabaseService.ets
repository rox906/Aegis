import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AuditLogEntry, EventType } from '../model/VaultModels';

const DB_NAME = 'aegis.db';

const CREATE_TABLE_AUDIT_LOGS = `CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type INTEGER NOT NULL,
  reference TEXT,
  timestamp INTEGER NOT NULL
)`;

const THIRTY_DAYS_MS: number = 30 * 24 * 60 * 60 * 1000;

export class DatabaseService {
  private static instance: DatabaseService | undefined = undefined;
  private rdbStore: relationalStore.RdbStore | undefined = undefined;

  private constructor() {
  }

  static getInstance(): DatabaseService {
    if (DatabaseService.instance === undefined) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  async init(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.rdbStore = await relationalStore.getRdbStore(context, config);
    await this.rdbStore.executeSql(CREATE_TABLE_AUDIT_LOGS);
  }

  async insertAuditLog(eventType: EventType, reference?: string): Promise<void> {
    if (this.rdbStore === undefined) {
      throw new Error('DatabaseService not initialized. Call init() first.');
    }
    const now = Date.now();
    const valueBucket: ValuesBucket = {
      'event_type': eventType as number,
      'reference': reference !== undefined ? reference : null,
      'timestamp': now
    };
    await this.rdbStore.insert('audit_logs', valueBucket);
  }

  async getAuditLogs(): Promise<AuditLogEntry[]> {
    if (this.rdbStore === undefined) {
      throw new Error('DatabaseService not initialized. Call init() first.');
    }
    const cutoff = Date.now() - THIRTY_DAYS_MS;
    const predicates = new relationalStore.RdbPredicates('audit_logs');
    predicates.greaterThanOrEqualTo('timestamp', cutoff);
    predicates.orderByDesc('timestamp');

    const resultSet = await this.rdbStore.query(predicates,
      ['id', 'event_type', 'reference', 'timestamp']);

    const logs: AuditLogEntry[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const id = resultSet.getLong(resultSet.getColumnIndex('id'));
        const eventTypeVal = resultSet.getLong(resultSet.getColumnIndex('event_type'));
        const refIndex = resultSet.getColumnIndex('reference');
        const reference = resultSet.isColumnNull(refIndex) ? '' : resultSet.getString(refIndex);
        const timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));

        const entry: AuditLogEntry = {
          id: id,
          eventType: eventTypeVal as EventType,
          reference: reference,
          timestamp: timestamp
        };
        logs.push(entry);
      }
    } finally {
      resultSet.close();
    }
    return logs;
  }
}

